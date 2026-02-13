<script setup lang="ts">
import { ref, onMounted } from 'vue'

const API_URL = 'http://localhost:3000'

interface User {
  id: string
  name: string
  email: string
  role: 'staff' | 'manager' | 'admin'
  status: 'active' | 'inactive'
  createdAt: string
}

interface UserForm {
  name: string
  email: string
  role: 'staff' | 'manager' | 'admin'
  status: 'active' | 'inactive'
}

const users = ref<User[]>([])
const loading = ref(false)
const error = ref('')
const editingUser = ref<User | null>(null)

const formData = ref<UserForm>({
  name: '',
  email: '',
  role: 'staff',
  status: 'active'
})

const fetchUsers = async () => {
  try {
    const response = await fetch(`${API_URL}/users`)
    const data = await response.json()
    users.value = data.users
  } catch (e) {
    error.value = 'Failed to fetch users'
  }
}

const resetForm = () => {
  formData.value = {
    name: '',
    email: '',
    role: 'staff',
    status: 'active'
  }
  editingUser.value = null
  error.value = ''
}

const addUser = async () => {
  if (!formData.value.name.trim() || !formData.value.email.trim()) {
    error.value = 'Name and email are required'
    return
  }

  loading.value = true
  error.value = ''

  try {
    const response = await fetch(`${API_URL}/users`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(formData.value)
    })

    const data = await response.json()

    if (response.ok) {
      resetForm()
      await fetchUsers()
    } else {
      error.value = data.error || 'Failed to add user'
    }
  } catch (e) {
    error.value = 'Failed to add user'
  } finally {
    loading.value = false
  }
}

const startEdit = (user: User) => {
  editingUser.value = user
  formData.value = {
    name: user.name,
    email: user.email,
    role: user.role,
    status: user.status
  }
}

const updateUser = async () => {
  if (!editingUser.value) return

  loading.value = true
  error.value = ''

  try {
    const response = await fetch(`${API_URL}/users/${editingUser.value.id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(formData.value)
    })

    const data = await response.json()

    if (response.ok) {
      resetForm()
      await fetchUsers()
    } else {
      error.value = data.error || 'Failed to update user'
    }
  } catch (e) {
    error.value = 'Failed to update user'
  } finally {
    loading.value = false
  }
}

const deleteUser = async (userId: string) => {
  if (!confirm('Are you sure you want to delete this user?')) return

  loading.value = true
  error.value = ''

  try {
    const response = await fetch(`${API_URL}/users/${userId}`, {
      method: 'DELETE'
    })

    if (response.ok) {
      await fetchUsers()
    } else {
      error.value = 'Failed to delete user'
    }
  } catch (e) {
    error.value = 'Failed to delete user'
  } finally {
    loading.value = false
  }
}

const getRoleBadgeClass = (role: string) => {
  const classes: Record<string, string> = {
    admin: 'badge-admin',
    manager: 'badge-manager',
    staff: 'badge-staff'
  }
  return classes[role] || ''
}

const getStatusBadgeClass = (status: string) => {
  return status === 'active' ? 'badge-active' : 'badge-inactive'
}

onMounted(fetchUsers)
</script>

<template>
  <div class="user-manager">
    <h1>Hotel User Management</h1>

    <div class="form-container">
      <h2>{{ editingUser ? 'Edit User' : 'Add New User' }}</h2>

      <form @submit.prevent="editingUser ? updateUser() : addUser()">
        <div class="form-row">
          <div class="form-group">
            <label for="name">Name *</label>
            <input
              id="name"
              v-model="formData.name"
              type="text"
              placeholder="Enter name"
              :disabled="loading"
              required
            />
          </div>

          <div class="form-group">
            <label for="email">Email *</label>
            <input
              id="email"
              v-model="formData.email"
              type="email"
              placeholder="Enter email"
              :disabled="loading"
              required
            />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="role">Role *</label>
            <select id="role" v-model="formData.role" :disabled="loading" required>
              <option value="staff">Staff</option>
              <option value="manager">Manager</option>
              <option value="admin">Admin</option>
            </select>
          </div>

          <div class="form-group">
            <label for="status">Status *</label>
            <select id="status" v-model="formData.status" :disabled="loading" required>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
          </div>
        </div>

        <p v-if="error" class="error">{{ error }}</p>

        <div class="form-actions">
          <button type="submit" class="btn-primary" :disabled="loading">
            {{ loading ? 'Saving...' : (editingUser ? 'Update User' : 'Add User') }}
          </button>
          <button
            v-if="editingUser"
            type="button"
            class="btn-secondary"
            @click="resetForm"
            :disabled="loading"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>

    <div class="users-list">
      <h2>Users ({{ users.length }})</h2>

      <div v-if="users.length" class="table-container">
        <table class="users-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="user in users" :key="user.id">
              <td>{{ user.name }}</td>
              <td>{{ user.email }}</td>
              <td>
                <span class="badge" :class="getRoleBadgeClass(user.role)">
                  {{ user.role }}
                </span>
              </td>
              <td>
                <span class="badge" :class="getStatusBadgeClass(user.status)">
                  {{ user.status }}
                </span>
              </td>
              <td>{{ new Date(user.createdAt).toLocaleDateString() }}</td>
              <td class="actions">
                <button
                  class="btn-edit"
                  @click="startEdit(user)"
                  :disabled="loading"
                  title="Edit user"
                >
                  Edit
                </button>
                <button
                  class="btn-delete"
                  @click="deleteUser(user.id)"
                  :disabled="loading"
                  title="Delete user"
                >
                  Delete
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="empty">No users yet. Add your first hotel staff member!</p>
    </div>
  </div>
</template>

<style scoped>
.user-manager {
  width: 100%;
  padding: 1rem;
}

h1 {
  color: var(--color-heading);
  margin-bottom: 1rem;
  font-size: 1.25rem;
}

h2 {
  color: var(--color-heading);
  margin-bottom: 0.75rem;
  font-size: 1rem;
}

.form-container {
  background: var(--color-background-soft);
  padding: 2rem;
  border-radius: 8px;
  margin-bottom: 2rem;
  border: 1px solid var(--color-border);
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-bottom: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
}

label {
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: var(--color-heading);
}

input,
select {
  padding: 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: 4px;
  font-size: 1rem;
  background: var(--color-background);
  color: var(--color-text);
}

input:focus,
select:focus {
  outline: none;
  border-color: hsla(160, 100%, 37%, 1);
}

.form-actions {
  display: flex;
  gap: 1rem;
  margin-top: 1.5rem;
}

.btn-primary,
.btn-secondary {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  font-weight: 500;
  transition: all 0.2s;
}

.btn-primary {
  background: hsla(160, 100%, 37%, 1);
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: hsla(160, 100%, 30%, 1);
}

.btn-secondary {
  background: hsla(220, 10%, 50%, 1);
  color: white;
}

.btn-secondary:hover:not(:disabled) {
  background: hsla(220, 10%, 40%, 1);
}

button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error {
  color: #e53935;
  margin: 1rem 0;
  padding: 0.75rem;
  background: rgba(229, 57, 53, 0.1);
  border-radius: 4px;
}

.users-list {
  background: var(--color-background-soft);
  padding: 2rem;
  border-radius: 8px;
  border: 1px solid var(--color-border);
}

.table-container {
  overflow-x: auto;
}

.users-table {
  width: 100%;
  border-collapse: collapse;
}

.users-table th,
.users-table td {
  padding: 1rem;
  text-align: left;
  border-bottom: 1px solid var(--color-border);
}

.users-table th {
  font-weight: 600;
  color: var(--color-heading);
  background: var(--color-background);
}

.users-table tr:last-child td {
  border-bottom: none;
}

.users-table tbody tr:hover {
  background: var(--color-background);
}

.badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.875rem;
  font-weight: 500;
  text-transform: capitalize;
}

.badge-admin {
  background: rgba(156, 39, 176, 0.2);
  color: #9c27b0;
}

.badge-manager {
  background: rgba(33, 150, 243, 0.2);
  color: #2196f3;
}

.badge-staff {
  background: rgba(76, 175, 80, 0.2);
  color: #4caf50;
}

.badge-active {
  background: rgba(76, 175, 80, 0.2);
  color: #4caf50;
}

.badge-inactive {
  background: rgba(158, 158, 158, 0.2);
  color: #9e9e9e;
}

.actions {
  display: flex;
  gap: 0.5rem;
}

.btn-edit,
.btn-delete {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all 0.2s;
}

.btn-edit {
  background: hsla(160, 100%, 37%, 1);
  color: white;
}

.btn-edit:hover:not(:disabled) {
  background: hsla(160, 100%, 30%, 1);
}

.btn-delete {
  background: #e53935;
  color: white;
}

.btn-delete:hover:not(:disabled) {
  background: #c62828;
}

.empty {
  color: var(--color-text);
  opacity: 0.7;
  text-align: center;
  padding: 2rem;
}

@media (max-width: 768px) {
  .form-row {
    grid-template-columns: 1fr;
  }

  .table-container {
    overflow-x: scroll;
  }
}
</style>
