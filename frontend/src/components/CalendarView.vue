<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, nextTick } from 'vue'

const API_URL = 'http://localhost:3000'

interface HousekeepingTask {
  id: string
  roomId: string
  roomNumber?: string
  assignedUserId: string
  assignedUserName?: string
  taskDate: string
  taskType: 'cleaning' | 'maintenance' | 'inspection' | 'turndown'
  priority: 'low' | 'medium' | 'high' | 'urgent'
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled'
  notes?: string
  startedAt?: string
  completedAt?: string
}

interface Room {
  id: string
  roomNumber: string
  roomTypeName?: string
  floor?: number
  status: string
}

const rooms = ref<Room[]>([])
const tasks = ref<HousekeepingTask[]>([])
const loading = ref(false)
const error = ref('')

// Date range controls
const yesterday = new Date()
yesterday.setDate(yesterday.getDate() - 1)
const startDate = ref(yesterday)
const daysToShow = ref(7)
const containerWidth = ref(0)
const transitionDirection = ref<'left' | 'right' | null>(null)

// Fixed column widths (must match CSS)
const ROOM_COLUMN_WIDTH = 120
const DATE_COLUMN_WIDTH = 100

// Drag and drop state
const draggedTask = ref<HousekeepingTask | null>(null)
const draggedFromDate = ref<string | null>(null)
const pendingMove = ref<{
  task: HousekeepingTask
  fromDate: string
  toDate: string
} | null>(null)

// Filter controls
const statusFilter = ref<string>('all')

const dates = computed(() => {
  const dateArray: Date[] = []
  for (let i = 0; i < daysToShow.value; i++) {
    const date = new Date(startDate.value)
    date.setDate(date.getDate() + i)
    dateArray.push(date)
  }
  return dateArray
})

const filteredRooms = computed(() => {
  let filtered = [...rooms.value]

  // Sort by room number
  filtered.sort((a, b) => {
    const numA = parseInt(a.roomNumber) || 0
    const numB = parseInt(b.roomNumber) || 0
    return numA - numB
  })

  return filtered
})

const fetchRooms = async () => {
  try {
    const response = await fetch(`${API_URL}/rooms`)
    const data = await response.json()
    rooms.value = data.rooms
  } catch (e) {
    error.value = 'Failed to fetch rooms'
  }
}

const fetchTasks = async () => {
  try {
    const response = await fetch(`${API_URL}/housekeeping-tasks`)
    const data = await response.json()
    tasks.value = data.tasks
  } catch (e) {
    error.value = 'Failed to fetch tasks'
  }
}

const getTasksForRoomAndDate = (roomId: string, date: Date): HousekeepingTask[] => {
  const dateStr = formatDateISO(date)
  let roomTasks = tasks.value.filter(t => t.roomId === roomId && t.taskDate === dateStr)

  if (statusFilter.value !== 'all') {
    roomTasks = roomTasks.filter(t => t.status === statusFilter.value)
  }

  return roomTasks
}

const formatDateISO = (date: Date): string => {
  return date.toISOString().split('T')[0]
}

const formatDateDisplay = (date: Date): string => {
  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

const formatDateHeader = (date: Date): string => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const compareDate = new Date(date)
  compareDate.setHours(0, 0, 0, 0)

  if (compareDate.getTime() === today.getTime()) {
    return 'Today'
  }

  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

const isToday = (date: Date): boolean => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const compareDate = new Date(date)
  compareDate.setHours(0, 0, 0, 0)
  return compareDate.getTime() === today.getTime()
}

const getStaffInitials = (name: string | undefined): string => {
  if (!name) return '?'
  const parts = name.split(' ')
  if (parts.length >= 2) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  }
  return name.substring(0, 2).toUpperCase()
}

const getStatusClass = (status: string): string => {
  const classes: Record<string, string> = {
    pending: 'task-pending',
    in_progress: 'task-in-progress',
    completed: 'task-completed',
    cancelled: 'task-cancelled'
  }
  return classes[status] || ''
}

const getTaskTypeIcon = (type: string): string => {
  const icons: Record<string, string> = {
    cleaning: '🧹',
    maintenance: '🔧',
    inspection: '🔍',
    turndown: '🛏️'
  }
  return icons[type] || '📋'
}

const navigateDays = (offset: number) => {
  // Set transition direction based on offset
  transitionDirection.value = offset > 0 ? 'right' : 'left'

  const newDate = new Date(startDate.value)
  newDate.setDate(newDate.getDate() + offset)
  startDate.value = newDate

  // Reset transition direction after animation
  setTimeout(() => {
    transitionDirection.value = null
  }, 400)
}

const goToToday = () => {
  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)
  startDate.value = yesterday
}

const changeDaysToShow = (days: number) => {
  daysToShow.value = days
}

const calculateDaysToShow = (width: number): number => {
  // Calculate available width for date columns
  const availableWidth = width - ROOM_COLUMN_WIDTH

  // Calculate how many date columns can fit
  const maxDays = Math.floor(availableWidth / DATE_COLUMN_WIDTH)

  // Minimum 3 days, maximum 30 days
  return Math.max(3, Math.min(30, maxDays))
}

const updateContainerWidth = () => {
  const container = document.querySelector('.calendar-container')
  if (container) {
    const width = container.clientWidth
    containerWidth.value = width
    daysToShow.value = calculateDaysToShow(width)
  }
}

// Drag and drop handlers
const handleDragStart = (task: HousekeepingTask, date: Date) => {
  draggedTask.value = task
  draggedFromDate.value = formatDateISO(date)
}

const handleDragOver = (event: DragEvent) => {
  event.preventDefault()
}

const handleDrop = (event: DragEvent, date: Date) => {
  event.preventDefault()

  if (!draggedTask.value || !draggedFromDate.value) return

  const newDate = formatDateISO(date)

  // Don't create pending move if dropping on same date
  if (newDate === draggedFromDate.value) {
    draggedTask.value = null
    draggedFromDate.value = null
    return
  }

  // Create pending move for confirmation
  pendingMove.value = {
    task: draggedTask.value,
    fromDate: draggedFromDate.value,
    toDate: newDate
  }

  draggedTask.value = null
  draggedFromDate.value = null
}

const confirmMove = async () => {
  if (!pendingMove.value) return

  loading.value = true
  error.value = ''

  try {
    const response = await fetch(`${API_URL}/housekeeping-tasks/${pendingMove.value.task.id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskDate: pendingMove.value.toDate
      })
    })

    if (response.ok) {
      pendingMove.value = null
      await fetchTasks()
    } else {
      const data = await response.json()
      error.value = data.error || 'Failed to move task'
      pendingMove.value = null
    }
  } catch (e) {
    error.value = 'Failed to move task'
    pendingMove.value = null
  } finally {
    loading.value = false
  }
}

const cancelMove = () => {
  pendingMove.value = null
}

onMounted(async () => {
  loading.value = true
  await Promise.all([fetchRooms(), fetchTasks()])
  loading.value = false

  // Wait for DOM to be fully rendered, then calculate initial days to show
  await nextTick()
  updateContainerWidth()

  // Update on window resize
  window.addEventListener('resize', updateContainerWidth)
})

onUnmounted(() => {
  window.removeEventListener('resize', updateContainerWidth)
})
</script>

<template>
  <div class="calendar-view">
    <div class="calendar-header">
      <h1>📅 Housekeeping Calendar</h1>
      <p>Visual schedule of room assignments</p>
    </div>

    <div class="calendar-controls">
      <div class="date-navigation">
        <button @click="navigateDays(-30)" class="nav-btn">
          ← Previous 30
        </button>
        <button @click="navigateDays(-7)" class="nav-btn">
          ← Previous 7
        </button>
        <button @click="goToToday" class="nav-btn today-btn">
          Today
        </button>
        <button @click="navigateDays(7)" class="nav-btn">
          Next 7 →
        </button>
        <button @click="navigateDays(30)" class="nav-btn">
          Next 30 →
        </button>
      </div>

      <div class="view-options">
        <div class="days-display">
          Showing {{ daysToShow }} days
        </div>

        <label>
          <span>Status:</span>
          <select v-model="statusFilter">
            <option value="all">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="in_progress">In Progress</option>
            <option value="completed">Completed</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </label>
      </div>
    </div>

    <div v-if="loading" class="loading">Loading calendar...</div>
    <p v-if="error" class="error">{{ error }}</p>

    <div v-if="!loading && filteredRooms.length > 0" class="calendar-container">
      <div class="calendar-grid">
        <!-- Fixed room column -->
        <div class="room-column">
          <div class="room-header">Room</div>
          <div
            v-for="room in filteredRooms"
            :key="room.id"
            class="room-cell"
          >
            <div class="room-number">{{ room.roomNumber }}</div>
            <div class="room-type">{{ room.roomTypeName }}</div>
            <div v-if="room.floor" class="room-floor">Floor {{ room.floor }}</div>
          </div>
        </div>

        <!-- Animated date columns -->
        <Transition :name="transitionDirection === 'left' ? 'slide-left' : 'slide-right'" mode="out-in">
          <div class="dates-section" :key="startDate.toISOString()">
            <!-- Date headers -->
            <div class="dates-header">
              <div
                v-for="date in dates"
                :key="date.toISOString()"
                class="date-header"
                :class="{ 'is-today': isToday(date) }"
              >
                <div class="date-day">{{ formatDateHeader(date) }}</div>
                <div class="date-number">{{ date.getDate() }}</div>
              </div>
            </div>

            <!-- Date cells for each room -->
            <div
              v-for="room in filteredRooms"
              :key="room.id"
              class="dates-row"
            >
              <div
                v-for="date in dates"
                :key="`${room.id}-${date.toISOString()}`"
                class="date-cell"
                :class="{ 'is-today': isToday(date), 'drop-target': draggedTask !== null }"
                @dragover="handleDragOver"
                @drop="handleDrop($event, date)"
              >
            <!-- Regular tasks -->
            <div
              v-for="task in getTasksForRoomAndDate(room.id, date)"
              :key="task.id"
              class="task-block"
              :class="getStatusClass(task.status)"
              :title="`${task.assignedUserName} - ${task.taskType} - ${task.status}`"
              draggable="true"
              @dragstart="handleDragStart(task, date)"
            >
              <div class="task-content">
                <div class="task-header">
                  <span class="task-icon">{{ getTaskTypeIcon(task.taskType) }}</span>
                  <span class="task-staff">{{ task.assignedUserName }}</span>
                </div>
                <div class="task-type">{{ task.taskType }}</div>
              </div>
            </div>

            <!-- Pending moved task (preview in new location) -->
            <div
              v-if="pendingMove && pendingMove.toDate === formatDateISO(date) && pendingMove.task.roomId === room.id"
              class="task-block task-pending-move"
              :class="getStatusClass(pendingMove.task.status)"
              :title="`${pendingMove.task.assignedUserName} - ${pendingMove.task.taskType} - Pending move`"
            >
              <div class="task-content">
                <div class="task-header">
                  <span class="task-icon">{{ getTaskTypeIcon(pendingMove.task.taskType) }}</span>
                  <span class="task-staff">{{ pendingMove.task.assignedUserName }}</span>
                </div>
                <div class="task-type">{{ pendingMove.task.taskType }}</div>
              </div>
            </div>

            <!-- Confirmation buttons (in new location where task was dropped) -->
            <div
              v-if="pendingMove && pendingMove.toDate === formatDateISO(date) && pendingMove.task.roomId === room.id"
              class="confirm-move"
            >
              <button class="btn-confirm" @click="confirmMove" :disabled="loading">
                ✓ Confirm
              </button>
              <button class="btn-cancel" @click="cancelMove" :disabled="loading">
                ✕ Cancel
              </button>
            </div>

                <div v-if="getTasksForRoomAndDate(room.id, date).length === 0 && (!pendingMove || pendingMove.fromDate !== formatDateISO(date) || pendingMove.task.roomId !== room.id)" class="empty-cell">
                  <!-- Empty cell -->
                </div>
              </div>
            </div>
          </div>
        </Transition>
      </div>
    </div>

    <div v-else-if="!loading" class="empty-state">
      <p>No rooms available. Add rooms to see the calendar.</p>
    </div>

    <!-- Legend -->
    <div class="calendar-legend">
      <h3>Legend</h3>
      <div class="legend-items">
        <div class="legend-item">
          <span class="legend-box task-pending"></span>
          <span>Pending</span>
        </div>
        <div class="legend-item">
          <span class="legend-box task-in-progress"></span>
          <span>In Progress</span>
        </div>
        <div class="legend-item">
          <span class="legend-box task-completed"></span>
          <span>Completed</span>
        </div>
        <div class="legend-item">
          <span class="legend-box task-cancelled"></span>
          <span>Cancelled</span>
        </div>
      </div>
      <div class="legend-items">
        <div class="legend-item">
          <span>🧹</span> Cleaning
        </div>
        <div class="legend-item">
          <span>🔧</span> Maintenance
        </div>
        <div class="legend-item">
          <span>🔍</span> Inspection
        </div>
        <div class="legend-item">
          <span>🛏️</span> Turndown
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.calendar-view {
  width: 100%;
  padding: 0.75rem;
}

.calendar-header {
  text-align: center;
  margin-bottom: 1rem;
}

.calendar-header h1 {
  color: var(--color-heading);
  margin-bottom: 0.25rem;
  font-size: 1.5rem;
}

.calendar-header p {
  color: var(--color-text);
  opacity: 0.8;
  font-size: 0.9rem;
}

.calendar-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding: 0.75rem;
  background: var(--color-background-soft);
  border-radius: 6px;
  border: 1px solid var(--color-border);
  flex-wrap: wrap;
  gap: 0.75rem;
}

.date-navigation {
  display: flex;
  gap: 0.4rem;
}

.nav-btn {
  padding: 0.5rem 1rem;
  background: var(--color-background);
  color: var(--color-text);
  border: 1px solid var(--color-border);
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.85rem;
  font-weight: 500;
  transition: all 0.2s;
}

.nav-btn:hover {
  background: var(--color-primary-light);
  border-color: var(--color-primary);
  color: var(--color-primary-dark);
}

.today-btn {
  background: var(--color-primary);
  color: white;
  border-color: var(--color-primary);
}

.today-btn:hover {
  background: var(--color-primary-hover);
}

.view-options {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  align-items: center;
}

.days-display {
  font-size: 0.85rem;
  color: var(--color-text);
  opacity: 0.8;
  padding: 0.5rem 0.75rem;
  background: var(--color-background);
  border-radius: 4px;
  border: 1px solid var(--color-border);
}

.view-options label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.95rem;
  color: var(--color-heading);
}

.view-options select {
  padding: 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: 4px;
  background: var(--color-background);
  color: var(--color-text);
  font-size: 0.95rem;
}

.loading {
  text-align: center;
  padding: 3rem;
  color: var(--color-text);
  opacity: 0.7;
}

.error {
  color: #e53935;
  padding: 1rem;
  background: rgba(229, 57, 53, 0.1);
  border-radius: 4px;
  margin-bottom: 1rem;
}

.calendar-container {
  background: var(--color-background-soft);
  border-radius: 8px;
  border: 1px solid var(--color-border);
  overflow-x: auto;
  overflow-y: visible;
  margin-bottom: 2rem;
  max-width: 100%;
  position: relative;
}

.calendar-grid {
  display: grid;
  grid-template-columns: 120px 1fr;
  width: 100%;
}

.room-column {
  display: grid;
  grid-template-rows: auto;
  background: var(--color-background);
  border-right: 1px solid var(--color-border);
}

.room-header {
  width: 120px;
  padding: 0.5rem;
  font-weight: 600;
  font-size: 0.85rem;
  color: var(--color-heading);
  background: var(--color-background);
  border-bottom: 2px solid var(--color-border);
  position: sticky;
  top: 0;
  z-index: 11;
}

.dates-section {
  display: grid;
  grid-template-rows: auto;
  overflow-x: visible;
}

.dates-header {
  display: flex;
  background: var(--color-background);
  border-bottom: 2px solid var(--color-border);
  position: sticky;
  top: 0;
  z-index: 10;
}

.dates-row {
  display: flex;
  border-bottom: 1px solid var(--color-border);
  min-height: 3rem;
  align-items: stretch;
}

.date-header {
  width: 100px;
  min-width: 100px;
  max-width: 100px;
  padding: 0.4rem 0.5rem;
  text-align: center;
  border-right: 1px solid var(--color-border);
  font-size: 0.75rem;
  background: var(--color-background);
}

.date-header.is-today {
  background: var(--color-primary-light);
  border-left: 2px solid var(--color-primary);
  border-right: 2px solid var(--color-primary);
}

.date-day {
  font-weight: 600;
  color: var(--color-heading);
  font-size: 0.7rem;
  margin-bottom: 0.1rem;
}

.date-number {
  font-size: 0.95rem;
  color: var(--color-text);
}

.room-cell {
  width: 120px;
  padding: 0.4rem 0.5rem;
  background: var(--color-background-soft);
  border-bottom: 1px solid var(--color-border);
  min-height: 3rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  position: sticky;
  left: 0;
  z-index: 1;
  line-height: 1.2;
}

.room-number {
  font-weight: 600;
  font-size: 0.9rem;
  color: var(--color-heading);
}

.room-type {
  font-size: 0.7rem;
  color: var(--color-text);
  opacity: 0.7;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.room-floor {
  display: none;
}

.date-cell {
  width: 100px;
  min-width: 100px;
  max-width: 100px;
  padding: 0.25rem;
  border-right: 1px solid var(--color-border);
  height: auto;
  min-height: 3rem;
  overflow: visible;
}

.date-cell.is-today {
  background: var(--color-primary-light);
  border-left: 2px solid var(--color-primary);
  border-right: 2px solid var(--color-primary);
  opacity: 0.3;
}

.date-cell.drop-target {
  background: var(--color-primary-light);
  opacity: 0.3;
  transition: background 0.2s;
}

.date-cell.drop-target:hover {
  background: var(--color-primary-light);
  opacity: 0.5;
  outline: 2px dashed var(--color-primary);
  outline-offset: -2px;
}

.empty-cell {
  min-height: 2rem;
}

.confirm-move {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.25rem;
}

.btn-confirm,
.btn-cancel {
  padding: 0.4rem 0.5rem;
  border: none;
  border-radius: 3px;
  cursor: pointer;
  font-size: 0.7rem;
  font-weight: 600;
  transition: all 0.15s;
  white-space: nowrap;
}

.btn-confirm {
  background: var(--color-primary);
  color: white;
}

.btn-confirm:hover:not(:disabled) {
  background: var(--color-primary-hover);
  transform: scale(1.02);
}

.btn-cancel {
  background: var(--status-cancelled);
  color: white;
}

.btn-cancel:hover:not(:disabled) {
  background: var(--status-cancelled);
  opacity: 0.8;
  transform: scale(1.02);
}

.btn-confirm:disabled,
.btn-cancel:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.task-block {
  padding: 0.3rem 0.4rem;
  border-radius: 3px;
  font-size: 0.7rem;
  cursor: move;
  transition: all 0.15s;
  border-left: 2px solid transparent;
  line-height: 1.2;
  margin-bottom: 0.25rem;
}

.task-block:hover {
  transform: scale(1.02);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
  z-index: 5;
  position: relative;
}

.task-block:active {
  cursor: grabbing;
  opacity: 0.7;
}

.task-pending-move {
  opacity: 0.6;
  border-style: dashed;
  animation: pulse 1s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% {
    opacity: 0.6;
  }
  50% {
    opacity: 0.8;
  }
}

.task-pending {
  background: var(--status-pending-bg);
  border-left-color: var(--status-pending);
  color: var(--color-text);
}

.task-in-progress {
  background: var(--status-in-progress-bg);
  border-left-color: var(--status-in-progress);
  color: var(--status-in-progress);
}

.task-completed {
  background: var(--status-completed-bg);
  border-left-color: var(--status-completed);
  color: var(--status-completed);
}

.task-cancelled {
  background: var(--status-cancelled-bg);
  border-left-color: var(--status-cancelled);
  color: var(--status-cancelled);
  opacity: 0.7;
}

.task-content {
  width: 100%;
}

.task-header {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  margin-bottom: 0.15rem;
}

.task-icon {
  font-size: 0.85rem;
  flex-shrink: 0;
}

.task-staff {
  font-weight: 600;
  font-size: 0.7rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
}

.task-type {
  font-size: 0.65rem;
  text-transform: capitalize;
  opacity: 0.85;
  font-style: italic;
}

.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--color-text);
  opacity: 0.7;
}

.calendar-legend {
  background: var(--color-background-soft);
  padding: 1rem;
  border-radius: 8px;
  border: 1px solid var(--color-border);
}

.calendar-legend h3 {
  color: var(--color-heading);
  margin-bottom: 0.75rem;
  font-size: 0.95rem;
}

.legend-items {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  margin-bottom: 0.75rem;
}

.legend-items:last-child {
  margin-bottom: 0;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.8rem;
  color: var(--color-text);
}

.legend-box {
  width: 16px;
  height: 16px;
  border-radius: 2px;
  border-left: 2px solid;
  flex-shrink: 0;
}

.legend-box.task-pending {
  background: rgba(158, 158, 158, 0.2);
  border-left-color: #757575;
}

.legend-box.task-in-progress {
  background: rgba(33, 150, 243, 0.2);
  border-left-color: #2196f3;
}

.legend-box.task-completed {
  background: rgba(76, 175, 80, 0.2);
  border-left-color: #4caf50;
}

.legend-box.task-cancelled {
  background: rgba(244, 67, 54, 0.15);
  border-left-color: #f44336;
}

@media (max-width: 1024px) {
  .calendar-controls {
    flex-direction: column;
    align-items: stretch;
  }

  .date-navigation {
    justify-content: center;
  }

  .view-options {
    justify-content: center;
  }
}

/* Slide transition animations - only for dates section */
.slide-left-enter-active,
.slide-left-leave-active,
.slide-right-enter-active,
.slide-right-leave-active {
  transition: transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1), opacity 0.3s ease;
}

/* Slide left (going backward) */
.slide-left-enter-from {
  transform: translateX(-50%);
  opacity: 0;
}

.slide-left-leave-to {
  transform: translateX(50%);
  opacity: 0;
}

/* Slide right (going forward) */
.slide-right-enter-from {
  transform: translateX(50%);
  opacity: 0;
}

.slide-right-leave-to {
  transform: translateX(-50%);
  opacity: 0;
}

.dates-section {
  position: relative;
}
</style>
