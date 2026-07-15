import { app, BrowserWindow } from "electron"
import path from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const harnessPath = fileURLToPath(import.meta.url)
const harnessArgumentIndex = process.argv.findIndex((argument) => path.resolve(argument) === harnessPath)
const [fixturePath, userDataPath] = process.argv
  .slice(harnessArgumentIndex + 1)
  .filter((argument) => argument !== "--")

let stage = "boot"
let window
let failed = false

const waitFor = async (promise, description, timeout = 45_000) => {
  let timeoutID
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timeoutID = setTimeout(() => reject(new Error(`${description} timed out after ${timeout / 1_000} seconds during ${stage}`)), timeout)
      }),
    ])
  } finally {
    clearTimeout(timeoutID)
  }
}

console.log("IndexedDB harness: boot")
app.once("will-finish-launching", () => console.log("IndexedDB harness: will-finish-launching"))
app.once("ready", () => console.log("IndexedDB harness: ready"))

try {
  if (harnessArgumentIndex < 0 || !fixturePath || !userDataPath) {
    throw new Error(`Expected fixture and temporary user-data paths; received argv: ${JSON.stringify(process.argv)}`)
  }

  const resolvedFixturePath = path.resolve(fixturePath)
  const resolvedUserDataPath = path.resolve(userDataPath)
  console.log(`IndexedDB harness: inputs fixture=${resolvedFixturePath} userData=${resolvedUserDataPath}`)
  app.setPath("userData", resolvedUserDataPath)
  if (!app.requestSingleInstanceLock()) throw new Error("IndexedDB harness could not acquire its temporary user-data single-instance lock")

  stage = "waiting for app ready"
  await waitFor(app.whenReady(), "Electron app readiness")
  stage = "creating hidden window"
  window = new BrowserWindow({
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  })
  window.webContents.once("did-finish-load", () => console.log("IndexedDB harness: window load"))
  stage = "loading renderer fixture"
  await waitFor(window.loadURL(pathToFileURL(resolvedFixturePath).href), "Renderer fixture load")
  stage = "running IndexedDB evidence"
  const result = await window.webContents.executeJavaScript("window.__OPENCHAMBER_INPUT_DRAFT_INDEXEDDB_EVIDENCE__")
  if (!result?.ok) throw new Error(result?.error ?? "Renderer did not return IndexedDB evidence")
  console.log(`Chromium IndexedDB evidence passed: ${result.evidence.map(({ name }) => name).join(", ")}`)
} catch (error) {
  failed = true
  const detail = error instanceof Error ? error.stack ?? error.message : String(error)
  console.error(`IndexedDB harness failed during ${stage}: ${detail}`)
  if (stage === "waiting for app ready") {
    console.error("IndexedDB harness requires an Electron-capable macOS GUI session; this environment delivered no Electron lifecycle events after boot.")
  }
} finally {
  window?.destroy()
  app.releaseSingleInstanceLock()
  app.exit(failed ? 1 : 0)
}
