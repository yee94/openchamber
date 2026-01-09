/**
 * ClawdHub API client
 * 
 * ClawdHub is a public skill registry at https://clawdhub.com
 * This client provides methods to fetch skills list and download skill packages.
 */

const CLAWDHUB_API_BASE = 'https://clawdhub.com/api/v1';

// Rate limiting: ClawdHub allows 120 requests/minute
const RATE_LIMIT_DELAY_MS = 100;
let lastRequestTime = 0;

async function rateLimitedFetch(url, options = {}) {
  const now = Date.now();
  const elapsed = now - lastRequestTime;
  if (elapsed < RATE_LIMIT_DELAY_MS) {
    await new Promise((resolve) => setTimeout(resolve, RATE_LIMIT_DELAY_MS - elapsed));
  }
  lastRequestTime = Date.now();

  const response = await fetch(url, {
    ...options,
    headers: {
      Accept: 'application/json',
      'User-Agent': 'OpenChamber/1.0',
      ...options.headers,
    },
  });

  return response;
}

/**
 * Fetch paginated list of skills from ClawdHub
 * @param {Object} options
 * @param {string} [options.cursor] - Pagination cursor from previous response
 * @returns {Promise<{ items: Array, nextCursor?: string }>}
 */
export async function fetchClawdHubSkills({ cursor } = {}) {
  const url = cursor
    ? `${CLAWDHUB_API_BASE}/skills?cursor=${encodeURIComponent(cursor)}`
    : `${CLAWDHUB_API_BASE}/skills`;

  const response = await rateLimitedFetch(url);

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`ClawdHub API error (${response.status}): ${text || response.statusText}`);
  }

  const data = await response.json();
  return {
    items: data.items || [],
    nextCursor: data.nextCursor || null,
  };
}

/**
 * Fetch details for a specific skill version
 * @param {string} slug - Skill slug/identifier
 * @param {string} [version='latest'] - Version string or 'latest'
 * @returns {Promise<{ skill: Object, version: Object }>}
 */
export async function fetchClawdHubSkillVersion(slug, version = 'latest') {
  // For 'latest', we need to first get the skill metadata to find the latest version
  if (version === 'latest') {
    const skillResponse = await rateLimitedFetch(`${CLAWDHUB_API_BASE}/skills/${encodeURIComponent(slug)}`);
    if (!skillResponse.ok) {
      throw new Error(`ClawdHub skill not found: ${slug}`);
    }
    const skillData = await skillResponse.json();
    const latestVersion = skillData.skill?.tags?.latest || skillData.latestVersion?.version;
    if (!latestVersion) {
      throw new Error(`No latest version found for skill: ${slug}`);
    }
    version = latestVersion;
  }

  const url = `${CLAWDHUB_API_BASE}/skills/${encodeURIComponent(slug)}/versions/${encodeURIComponent(version)}`;
  const response = await rateLimitedFetch(url);

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`ClawdHub version error (${response.status}): ${text || response.statusText}`);
  }

  return response.json();
}

/**
 * Download a skill package as a ZIP buffer
 * @param {string} slug - Skill slug/identifier
 * @param {string} version - Specific version string
 * @returns {Promise<ArrayBuffer>} - ZIP file contents
 */
export async function downloadClawdHubSkill(slug, version) {
  const url = `${CLAWDHUB_API_BASE}/download?slug=${encodeURIComponent(slug)}&version=${encodeURIComponent(version)}`;

  const response = await rateLimitedFetch(url, {
    headers: {
      Accept: 'application/zip',
    },
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`ClawdHub download error (${response.status}): ${text || response.statusText}`);
  }

  return response.arrayBuffer();
}

/**
 * Get skill metadata without version details
 * @param {string} slug - Skill slug/identifier
 * @returns {Promise<Object>}
 */
export async function fetchClawdHubSkillInfo(slug) {
  const url = `${CLAWDHUB_API_BASE}/skills/${encodeURIComponent(slug)}`;
  const response = await rateLimitedFetch(url);

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`ClawdHub skill error (${response.status}): ${text || response.statusText}`);
  }

  return response.json();
}
