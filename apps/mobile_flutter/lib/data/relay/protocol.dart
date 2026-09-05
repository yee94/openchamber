/// Official OpenChamber private-relay contract.
/// Normative source: `packages/ui/src/lib/relay/protocol.ts`.
library;

const relayProtocolVersion = 1;
const relayHkdfInfo = 'openchamber-relay-v1';

const encryptedFrameVersion = 1;
const encryptedFrameIvBytes = 12;
const encryptedFrameHeaderBytes = 1 + encryptedFrameIvBytes;
const maxPlaintextFrameBytes = 64 * 1024;

const tunnelFrameHeaderBytes = 5;
const tunnelFragmentFlag = 0x80;

const batchContainerTagSingle = 0x00;
const batchContainerTagBatch = 0x01;
const batchFrameLengthBytes = 4;
const batchEnvelopeReservedBytes = 1 + batchFrameLengthBytes;
const maxTunnelPayloadBytes = maxPlaintextFrameBytes - tunnelFrameHeaderBytes - batchEnvelopeReservedBytes;

const handshakeNonceBytes = 16;
const sessionKeyBytes = 32;
const gcmTagBytes = 16;
const ivPrefixBytes = 4;
const ivCounterBytes = 8;

abstract final class TunnelFrameType {
  static const httpRequest = 1;
  static const httpBody = 2;
  static const httpResponse = 3;
  static const streamEnd = 4;
  static const streamAbort = 5;
  static const wsOpen = 6;
  static const wsOpened = 7;
  static const wsText = 8;
  static const wsBinary = 9;
  static const wsClose = 10;
  static const ping = 11;
  static const pong = 12;

  static bool isKnown(int value) => value >= httpRequest && value <= pong;
}

abstract final class RelayCloseCode {
  static const controlReplaced = 4001;
  static const duplicateClient = 4002;
  static const stuckControlReset = 4003;
  static const hostUnavailable = 4008;
  static const authFailed = 4010;
  static const limitExceeded = 4029;
  static const hostWentAway = 1012;
  static const rekeyMismatch = 1008;
  static const channelFailure = 1011;
}

const terminalRelayCloseCodes = {
  RelayCloseCode.authFailed,
  RelayCloseCode.duplicateClient,
  RelayCloseCode.limitExceeded,
};
