use chrono::Utc;
use log::{info, warn};
use serde::{Deserialize, Serialize};
use serde_json::json;
use tauri::AppHandle;
use tauri::State;
use uuid::Uuid;

use crate::path_utils::expand_tilde_path;
use crate::DesktopRuntime;

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectoryPermissionRequest {
    path: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectoryPermissionResult {
    success: bool,
    path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    project_id: Option<String>,
    error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartAccessingResult {
    success: bool,
    error: Option<String>,
}

/// Process directory selection from frontend.
/// Updates settings (projects, activeProjectId, lastDirectory).
#[tauri::command]
pub async fn process_directory_selection(
    path: String,
    state: State<'_, DesktopRuntime>,
) -> Result<DirectoryPermissionResult, String> {
    // Validate directory exists
    let mut path_buf = expand_tilde_path(&path);
    if let Ok(canonicalized) = std::fs::canonicalize(&path_buf) {
        path_buf = canonicalized;
    }
    let normalized_path = path_buf.to_string_lossy().to_string();
    if !path_buf.exists() {
        return Ok(DirectoryPermissionResult {
            success: false,
            path: None,
            project_id: None,
            error: Some("Directory does not exist".to_string()),
        });
    }

    if !path_buf.is_dir() {
        return Ok(DirectoryPermissionResult {
            success: false,
            path: None,
            project_id: None,
            error: Some("Path is not a directory".to_string()),
        });
    }

    // Update settings with projects + activeProjectId + lastDirectory
    let now = Utc::now().timestamp_millis();
    let normalized_path_for_update = normalized_path.clone();

    let (_, project_id) = state
        .settings()
        .update_with(|mut settings| {
            if !settings.is_object() {
                settings = json!({});
            }

            let project_id = {
                let obj = settings.as_object_mut().unwrap();

                let projects_value = obj.entry("projects").or_insert_with(|| json!([]));
                if !projects_value.is_array() {
                    *projects_value = json!([]);
                }

                let projects = projects_value.as_array_mut().unwrap();

                let existing_index = projects.iter().position(|entry| {
                    entry
                        .get("path")
                        .and_then(|value| value.as_str())
                        .map(|value| value == normalized_path_for_update)
                        .unwrap_or(false)
                });

                if let Some(index) = existing_index {
                    let entry = projects
                        .get_mut(index)
                        .and_then(|value| value.as_object_mut());
                    if let Some(entry) = entry {
                        entry.insert("lastOpenedAt".to_string(), json!(now));
                        if let Some(id) = entry.get("id").and_then(|value| value.as_str()) {
                            id.to_string()
                        } else {
                            let id = Uuid::new_v4().to_string();
                            entry.insert("id".to_string(), json!(id));
                            id
                        }
                    } else {
                        let id = Uuid::new_v4().to_string();
                        projects[index] = json!({
                            "id": id,
                            "path": normalized_path_for_update,
                            "addedAt": now,
                            "lastOpenedAt": now
                        });
                        id
                    }
                } else {
                    let id = Uuid::new_v4().to_string();
                    projects.push(json!({
                        "id": id,
                        "path": normalized_path_for_update,
                        "addedAt": now,
                        "lastOpenedAt": now
                    }));
                    id
                }
            };

            if let Some(obj) = settings.as_object_mut() {
                obj.insert("activeProjectId".to_string(), json!(project_id.clone()));
                obj.insert(
                    "lastDirectory".to_string(),
                    json!(normalized_path_for_update),
                );
            }

            (settings, project_id)
        })
        .await
        .map_err(|e| format!("Failed to save updated settings: {}", e))?;

    info!(
        "[permissions] Updated settings with active project {}: {}",
        project_id, normalized_path
    );

    Ok(DirectoryPermissionResult {
        success: true,
        path: Some(normalized_path),
        project_id: Some(project_id),
        error: None,
    })
}

/// Legacy directory picker command (frontend handles actual dialog)
#[tauri::command]
pub async fn pick_directory(
    _app_handle: AppHandle,
    _state: State<'_, DesktopRuntime>,
) -> Result<DirectoryPermissionResult, String> {
    Ok(DirectoryPermissionResult {
        success: false,
        path: None,
        project_id: None,
        error: Some(
            "Use requestDirectoryAccess instead - it handles native dialog properly".to_string(),
        ),
    })
}

/// Request directory access (desktop implementation)
/// For unsandboxed apps, just validates the path is accessible
#[tauri::command]
pub async fn request_directory_access(
    request: DirectoryPermissionRequest,
    _state: State<'_, DesktopRuntime>,
) -> Result<DirectoryPermissionResult, String> {
    let path = request.path;

    let mut path_buf = expand_tilde_path(&path);
    if let Ok(canonicalized) = std::fs::canonicalize(&path_buf) {
        path_buf = canonicalized;
    }
    let normalized_path = path_buf.to_string_lossy().to_string();
    if !path_buf.exists() {
        return Ok(DirectoryPermissionResult {
            success: false,
            path: None,
            project_id: None,
            error: Some("Directory does not exist".to_string()),
        });
    }

    if !path_buf.is_dir() {
        return Ok(DirectoryPermissionResult {
            success: false,
            path: None,
            project_id: None,
            error: Some("Path is not a directory".to_string()),
        });
    }

    // For unsandboxed apps, no bookmark needed - just verify access
    match std::fs::read_dir(&path_buf) {
        Ok(_) => Ok(DirectoryPermissionResult {
            success: true,
            path: Some(normalized_path),
            project_id: None,
            error: None,
        }),
        Err(e) => Ok(DirectoryPermissionResult {
            success: false,
            path: None,
            project_id: None,
            error: Some(format!("Cannot access directory: {}", e)),
        }),
    }
}

/// Start accessing directory (desktop implementation)
#[tauri::command]
pub async fn start_accessing_directory(
    path: String,
    _state: State<'_, DesktopRuntime>,
) -> Result<StartAccessingResult, String> {
    // Check if directory exists and is accessible
    let path_buf = std::path::PathBuf::from(&path);

    if !path_buf.exists() {
        return Ok(StartAccessingResult {
            success: false,
            error: Some("Directory does not exist".to_string()),
        });
    }

    if !path_buf.is_dir() {
        return Ok(StartAccessingResult {
            success: false,
            error: Some("Path is not a directory".to_string()),
        });
    }

    // Try to read the directory to verify access
    match std::fs::read_dir(&path_buf) {
        Ok(_) => {
            info!("Successfully started accessing directory: {}", path);
            Ok(StartAccessingResult {
                success: true,
                error: None,
            })
        }
        Err(e) => {
            warn!("Failed to access directory {}: {}", path, e);
            Ok(StartAccessingResult {
                success: false,
                error: Some(format!("Failed to access directory: {}", e)),
            })
        }
    }
}

/// Stop accessing directory (desktop implementation)
#[tauri::command]
pub async fn stop_accessing_directory(
    _path: String,
    _state: State<'_, DesktopRuntime>,
) -> Result<StartAccessingResult, String> {
    // For Stage 1, just confirm the operation
    // Full implementation would call stopAccessingSecurityScopedResource
    info!("Stopped accessing directory");
    Ok(StartAccessingResult {
        success: true,
        error: None,
    })
}

/// Restore bookmarks on app startup (no-op for unsandboxed apps)
#[tauri::command]
pub async fn restore_bookmarks_on_startup(_state: State<'_, DesktopRuntime>) -> Result<(), String> {
    // For unsandboxed apps, no bookmarks needed
    // Directory access is restored from settings.lastDirectory
    info!("[permissions] Bookmark restore not needed for unsandboxed app");
    Ok(())
}
