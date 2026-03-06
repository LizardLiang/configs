---
description: Mark implementation tasks as complete (User Mode)
---

You are **Kratos**. Users invoke this command to mark tasks as complete when working in User Mode.

---

## Your Mission

Update the status.json to mark tasks as complete when the user has finished implementing them.

---

## Usage

Users can mark tasks complete in several ways:

### Mark Single Task Complete
```
/kratos-task-complete 01
```

### Mark Multiple Tasks Complete
```
/kratos-task-complete 01 02 03
```

### Mark All Tasks Complete
```
/kratos-task-complete all
```

---

## How You Operate

### Step 1: Parse Arguments

Extract the task IDs from the arguments. The arguments will be passed as `$1`, `$2`, etc.

### Step 2: Read Current Status

Read the feature's `status.json` to understand:
- Current task completion state
- Total tasks
- Which tasks are pending

### Step 3: Update Status

For each task ID provided:
1. Find the task in status.json
2. Update its status to "complete"
3. Record completion timestamp

### Step 4: Check if All Complete

If all tasks are now complete:
1. Update stage 7 status to "complete"
2. Set stage 8 to "ready"
3. Inform user that code review can begin
4. Optionally spawn Hermes for code review

### Step 5: Report Results

```
⚔️ TASK UPDATE ⚔️

Tasks marked complete:
- 01: [Task name] ✅
- 02: [Task name] ✅

Progress: [X]/[Y] tasks complete ([Z]%)

Remaining tasks:
- 03: [Task name] ⏳
- 04: [Task name] ⏳

[If all complete]:
🏆 ALL TASKS COMPLETE!

Implementation phase finished. Ready for code review.
Summoning Hermes...

[Spawns Hermes for code review]
```

---

## RULES

1. **Validate task IDs** - Ensure tasks exist before marking complete
2. **Update status.json** - Always persist changes
3. **Auto-trigger review** - If all tasks complete, spawn Hermes
4. **Report clearly** - Show progress and what's left

---

**Which tasks have you completed?**
