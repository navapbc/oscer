import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-upload"
export default class extends Controller {
  static targets = ["fileInput", "submitButton", "storageKey", "filename", "progress", "errorMessage"]

  connect() {
    this.submitButtonTarget.disabled = true
    this.isUploading = false
    this.boundPreventUnload = this.preventUnload.bind(this)
  }

  selectFile() {
    // Enable submit button when file is selected
    const file = this.fileInputTarget.files[0]
    this.submitButtonTarget.disabled = !file
  }

  async uploadFile(event) {
    event.preventDefault()
    this.submitButtonTarget.disabled = true
    this.isUploading = true
    window.addEventListener('beforeunload', this.boundPreventUnload)

    const MAX_FILE_SIZE = 100 * 1024 * 1024 // 100MB

    const file = this.fileInputTarget.files[0]
    if (!file) {
      this.showError("Please select a file to upload")
      this.submitButtonTarget.disabled = false
      this.isUploading = false
      window.removeEventListener('beforeunload', this.boundPreventUnload)
      return
    }

    // Validate file size
    if (file.size > MAX_FILE_SIZE) {
      this.showError(`File too large. Maximum size is ${MAX_FILE_SIZE / 1024 / 1024}MB`)
      this.submitButtonTarget.disabled = false
      this.isUploading = false
      window.removeEventListener('beforeunload', this.boundPreventUnload)
      return
    }

    // Validate file type
    if (!file.name.endsWith('.csv')) {
      this.showError("Please select a CSV file")
      this.submitButtonTarget.disabled = false
      this.isUploading = false
      window.removeEventListener('beforeunload', this.boundPreventUnload)
      return
    }

    try {
      // Show progress and hide errors
      this.showProgress()
      this.hideError()

      // Step 1: Get presigned URL from backend
      const urlResponse = await fetch('/staff/certification_batch_uploads/presigned_url', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ filename: file.name })
      })

      if (!urlResponse.ok) {
        const errorData = await urlResponse.json().catch(() => ({}))
        throw new Error(errorData.error || 'Failed to get upload URL')
      }

      const { url, key } = await urlResponse.json()

      // Step 2: Upload directly to S3
      const uploadResponse = await fetch(url, {
        method: 'PUT',
        headers: { 'Content-Type': 'text/csv' },
        body: file
      })

      if (!uploadResponse.ok) {
        throw new Error('Failed to upload file to storage')
      }

      // Step 3: Populate hidden fields and submit form
      this.storageKeyTarget.value = key
      this.filenameTarget.value = file.name
      this.element.submit()

    } catch (error) {
      this.hideProgress()
      this.submitButtonTarget.disabled = false
      this.isUploading = false
      window.removeEventListener('beforeunload', this.boundPreventUnload)

      let message = 'Upload failed: '
      if (!navigator.onLine) {
        message += 'No internet connection. Please check your network.'
      } else if (error.message.includes('Failed to get upload URL')) {
        message += 'Could not prepare upload. Please try again or contact support.'
      } else if (error.message.includes('Failed to upload')) {
        message += 'File upload failed. Please check your connection and try again.'
      } else {
        message += error.message
      }
      this.showError(message)
    }
  }

  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    if (!token) {
      throw new Error('CSRF token not found. Please refresh the page.')
    }
    return token.content
  }

  preventUnload(e) {
    if (this.isUploading) {
      e.preventDefault()
      e.returnValue = ''
    }
  }

  showProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove('display-none')
    }
  }

  hideProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add('display-none')
    }
  }

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove('display-none')
    } else {
      alert(message)
    }
  }

  hideError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add('display-none')
    }
  }
}
