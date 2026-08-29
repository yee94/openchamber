const HEADER_SEPARATOR = Buffer.from('\r\n\r\n', 'utf8');

export const encodeLspFrame = (jsonBody) => {
  const body = Buffer.from(jsonBody, 'utf8');
  const header = Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, 'utf8');
  return Buffer.concat([header, body]);
};

export const createLspStdoutParser = (onMessage) => {
  let buffer = Buffer.alloc(0);

  const push = (chunk) => {
    if (!chunk || chunk.length === 0) {
      return;
    }
    buffer = Buffer.concat([buffer, Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)]);

    while (true) {
      const headerEnd = buffer.indexOf(HEADER_SEPARATOR);
      if (headerEnd === -1) {
        return;
      }

      const header = buffer.subarray(0, headerEnd).toString('utf8');
      const match = header.match(/Content-Length:\s*(\d+)/i);
      if (!match) {
        buffer = buffer.subarray(headerEnd + HEADER_SEPARATOR.length);
        continue;
      }

      const length = Number(match[1]);
      if (!Number.isFinite(length) || length < 0 || length > 16 * 1024 * 1024) {
        buffer = buffer.subarray(headerEnd + HEADER_SEPARATOR.length);
        continue;
      }

      const bodyStart = headerEnd + HEADER_SEPARATOR.length;
      if (buffer.length < bodyStart + length) {
        return;
      }

      const body = buffer.subarray(bodyStart, bodyStart + length).toString('utf8');
      buffer = buffer.subarray(bodyStart + length);
      onMessage(body);
    }
  };

  return { push };
};
