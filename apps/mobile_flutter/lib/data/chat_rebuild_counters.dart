/// Operation counters for chat list / row / reasoning rebuild isolation.
///
/// Widget tests assert these. They are not a systrace and do not prove a
/// mid-range phone GPU path.
class ChatRebuildCounters {
  ChatRebuildCounters._();

  static int listStructureBuilds = 0;
  static int rowWidgetBuilds = 0;
  static int rowSlotBuilds = 0;
  static int reasoningBuilds = 0;
  static final Map<String, int> rowWidgetBuildsById = {};
  static final Map<String, int> rowSlotBuildsById = {};
  static final Map<String, int> reasoningBuildsById = {};

  static void reset() {
    listStructureBuilds = 0;
    rowWidgetBuilds = 0;
    rowSlotBuilds = 0;
    reasoningBuilds = 0;
    rowWidgetBuildsById.clear();
    rowSlotBuildsById.clear();
    reasoningBuildsById.clear();
  }

  static void recordListStructure() => listStructureBuilds += 1;

  static void recordRowWidget(String id) {
    rowWidgetBuilds += 1;
    rowWidgetBuildsById[id] = (rowWidgetBuildsById[id] ?? 0) + 1;
  }

  static void recordRowSlot(String id) {
    rowSlotBuilds += 1;
    rowSlotBuildsById[id] = (rowSlotBuildsById[id] ?? 0) + 1;
  }

  static void recordReasoning(String id) {
    reasoningBuilds += 1;
    reasoningBuildsById[id] = (reasoningBuildsById[id] ?? 0) + 1;
  }

  static int rowWidgetBuildsFor(String id) => rowWidgetBuildsById[id] ?? 0;

  static int rowSlotBuildsFor(String id) => rowSlotBuildsById[id] ?? 0;

  static int reasoningBuildsFor(String id) => reasoningBuildsById[id] ?? 0;
}
