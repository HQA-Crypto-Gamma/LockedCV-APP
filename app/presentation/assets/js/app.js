(() => {
  const onReady = (callback) => {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback);
      return;
    }

    callback();
  };

  const setHidden = (element, hidden) => {
    if (element) element.hidden = hidden;
  };

  const setText = (element, text) => {
    if (element) element.textContent = text;
  };

  const showModal = (modal, focusTarget) => {
    if (!modal) return;

    modal.hidden = false;
    if (focusTarget) window.setTimeout(() => focusTarget.focus(), 0);
  };

  const hideModal = (modal) => {
    if (modal) modal.hidden = true;
  };

  const downloadBlob = (blob, filename) => {
    const downloadUrl = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = downloadUrl;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(downloadUrl);
  };

  const bindUploadPicker = () => {
    const cvUpload = document.getElementById('cv-upload');
    const cvUploadTitle = document.getElementById('cv-upload-title');
    const cvUploadMeta = document.getElementById('cv-upload-meta');
    const cvUploadSubmit = document.getElementById('cv-upload-submit');
    if (!cvUpload || !cvUploadTitle || !cvUploadMeta || !cvUploadSubmit) return;

    cvUpload.addEventListener('change', () => {
      const file = cvUpload.files && cvUpload.files[0];

      cvUploadTitle.textContent = file ? file.name : 'Choose a file';
      cvUploadMeta.textContent = file ? 'Ready to upload' : 'Only PDF';
      cvUploadSubmit.disabled = !file;
    });
  };

  const bindConfirmForms = () => {
    document.addEventListener('submit', (event) => {
      const submitter = event.submitter;
      const message = submitter && submitter.dataset.confirmMessage;
      if (message && !window.confirm(message)) event.preventDefault();
    });
  };

  const bindCopyButton = (copyButton, input, setStatus) => {
    if (!copyButton || !input) return;

    copyButton.addEventListener('click', () => {
      if (!input.value) return;

      const fallbackCopy = () => {
        input.select();
        document.execCommand('copy');
        setStatus('Copied.');
      };

      if (!navigator.clipboard) {
        fallbackCopy();
        return;
      }

      navigator.clipboard.writeText(input.value)
        .then(() => setStatus('Copied.'))
        .catch(fallbackCopy);
    });
  };

  const bindScanPage = () => {
    const workspace = document.querySelector('.scan-workspace[data-pdf-preview-url]');
    if (!workspace) return;

    const previewUrl = workspace.dataset.pdfPreviewUrl;
    const createUrl = workspace.dataset.pdfCreateUrl;
    const previewFrame = workspace.querySelector('[data-pdf-preview-frame]');
    const status = workspace.querySelector('.status-pill');
    const pageTitle = document.querySelector('[data-scan-page-title]');
    const previewTitle = workspace.querySelector('[data-scan-preview-title]');
    const heroMeta = document.querySelector('[data-scan-hero-meta]');
    const fieldsPanel = workspace.querySelector('[data-mask-fields-panel]');
    const reviewPanel = workspace.querySelector('[data-mask-review-panel]');
    const confirmPanel = document.querySelector('[data-mask-confirm-panel]');
    const nextButton = workspace.querySelector('[data-next-mask-step-button]');
    const backButton = document.querySelector('[data-back-mask-step-button]');
    const createButton = document.querySelector('[data-create-pdf-button]');
    const savedActions = document.querySelector('[data-saved-mask-actions]');
    const downloadButton = document.querySelector('[data-download-mask-button]');
    const shareButton = document.querySelector('[data-share-mask-button]');
    const passwordModal = document.querySelector('[data-password-modal]');
    const passwordForm = document.querySelector('[data-password-form]');
    const passwordInput = document.querySelector('[data-password-input]');
    const passwordError = document.querySelector('[data-password-error]');
    const passwordSubmitButton = document.querySelector('[data-password-submit-button]');
    const passwordCloseButtons = Array.from(document.querySelectorAll('[data-password-modal-close]'));
    const shareModal = document.querySelector('[data-share-link-modal]');
    const shareInput = document.querySelector('[data-share-link-input]');
    const shareStatus = document.querySelector('[data-share-link-status]');
    const shareCopyButton = document.querySelector('[data-share-link-copy-button]');
    const shareCloseButtons = Array.from(document.querySelectorAll('[data-share-link-modal-close]'));
    const createStatus = document.querySelector('[data-create-pdf-status]');
    const reviewStatus = workspace.querySelector('[data-review-step-status]');
    const checkboxes = Array.from(workspace.querySelectorAll('[data-mask-label-checkbox]'));
    if (!previewUrl || !previewFrame || checkboxes.length === 0) return;

    let debounceTimer;
    let currentPdfUrl;
    let requestId = 0;

    const selectedLabels = () => checkboxes
      .filter((checkbox) => checkbox.checked)
      .map((checkbox) => checkbox.value);

    const setStatus = (text) => setText(status, text);
    const setCreateStatus = (text) => setText(createStatus, text);
    const setReviewStatus = (text) => setText(reviewStatus, text);
    const setShareStatus = (text, failed = false) => {
      if (!shareStatus) return;

      shareStatus.textContent = text;
      shareStatus.hidden = false;
      shareStatus.classList.toggle('is-error', failed);
    };

    const showPasswordModal = () => {
      if (passwordError) passwordError.hidden = true;
      if (passwordInput) passwordInput.value = '';
      showModal(passwordModal, passwordInput);
    };

    const showShareModal = (shareUrl) => {
      if (!shareModal || !shareInput) return;

      shareInput.value = shareUrl;
      setHidden(shareStatus, true);
      showModal(shareModal, shareInput);
      window.setTimeout(() => shareInput.select(), 0);
    };

    const clearSavedState = () => {
      delete workspace.dataset.maskedAttachmentId;
      delete workspace.dataset.maskedAttachmentName;
      setCreateStatus('Not saved');
      setHidden(createButton, false);
      setHidden(savedActions, true);
    };

    const showReviewStep = () => {
      setHidden(reviewPanel, false);
      setHidden(fieldsPanel, false);
      setHidden(confirmPanel, true);
      setHidden(savedActions, true);
      workspace.classList.remove('scan-workspace--confirm');
      workspace.classList.add('scan-workspace--review');
      setText(pageTitle, 'Mask Review');
      setText(previewTitle, 'Masked PDF');
      setHidden(heroMeta, false);
      setReviewStatus('Review the preview before saving.');
    };

    const showConfirmStep = () => {
      setHidden(reviewPanel, true);
      setHidden(fieldsPanel, true);
      setHidden(confirmPanel, false);
      workspace.classList.remove('scan-workspace--review');
      workspace.classList.add('scan-workspace--confirm');
      setText(pageTitle, 'Confirm Masked PDF');
      setText(previewTitle, 'Final masked PDF');
      setHidden(heroMeta, true);

      if (workspace.dataset.maskedAttachmentId) {
        setHidden(createButton, true);
        setHidden(savedActions, false);
        setCreateStatus(workspace.dataset.maskedAttachmentName ? `Saved ${workspace.dataset.maskedAttachmentName}` : 'Saved');
      } else {
        setHidden(createButton, false);
        setHidden(savedActions, true);
        setCreateStatus('Not saved');
      }
    };

    const updatePreview = () => {
      const currentRequest = requestId + 1;
      requestId = currentRequest;
      setStatus('Updating');

      fetch(previewUrl, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Accept': 'application/pdf',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ selected_labels: selectedLabels() })
      })
        .then((response) => {
          if (!response.ok) throw new Error('Preview failed');
          return response.blob();
        })
        .then((pdfBlob) => {
          if (currentRequest !== requestId) return;
          if (currentPdfUrl) URL.revokeObjectURL(currentPdfUrl);
          currentPdfUrl = URL.createObjectURL(pdfBlob);
          previewFrame.src = `${currentPdfUrl}#toolbar=0&navpanes=0&scrollbar=1`;
          setStatus('Ready');
          setReviewStatus('Review the preview before saving.');
        })
        .catch(() => {
          if (currentRequest !== requestId) return;
          setStatus('Error');
          setReviewStatus('Preview failed.');
        });
    };

    checkboxes.forEach((checkbox) => {
      checkbox.addEventListener('change', () => {
        window.clearTimeout(debounceTimer);
        debounceTimer = window.setTimeout(updatePreview, 350);
        clearSavedState();
        setReviewStatus('Preview updating.');
      });
    });

    if (nextButton) nextButton.addEventListener('click', showConfirmStep);
    if (backButton) backButton.addEventListener('click', showReviewStep);

    if (createButton && createUrl) {
      createButton.addEventListener('click', () => {
        createButton.disabled = true;
        setCreateStatus('Saving');

        fetch(createUrl, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ selected_labels: selectedLabels() })
        })
          .then((response) => {
            if (!response.ok) throw new Error('Create failed');
            return response.json();
          })
          .then((payload) => {
            workspace.dataset.maskedAttachmentId = payload.masked_attachment_id || '';
            workspace.dataset.maskedAttachmentName = payload.attachment_name || '';
            setCreateStatus(payload.attachment_name ? `Saved ${payload.attachment_name}` : 'Saved');
            setHidden(createButton, true);
            setHidden(savedActions, false);
            setStatus('Saved');
          })
          .catch(() => {
            setCreateStatus('Error');
          })
          .finally(() => {
            createButton.disabled = false;
          });
      });
    }

    if (downloadButton) {
      downloadButton.addEventListener('click', () => {
        if (workspace.dataset.maskedAttachmentId) showPasswordModal();
      });
    }

    if (shareButton) {
      shareButton.addEventListener('click', () => {
        if (!workspace.dataset.maskedAttachmentId) return;

        shareButton.disabled = true;
        shareButton.textContent = 'Creating...';
        fetch(`${createUrl}/${workspace.dataset.maskedAttachmentId}/share_links`, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: '{}'
        })
          .then((response) => {
            if (!response.ok) throw new Error('Share link failed');
            return response.json();
          })
          .then((payload) => {
            showShareModal(payload.share_url);
          })
          .catch(() => {
            showShareModal('');
            setShareStatus('Could not create a share link.', true);
          })
          .finally(() => {
            shareButton.disabled = false;
            shareButton.textContent = 'Share';
          });
      });
    }

    const downloadEncryptedPdf = (password) => {
      if (!downloadButton || !workspace.dataset.maskedAttachmentId) return;

      if (passwordSubmitButton) passwordSubmitButton.disabled = true;
      downloadButton.disabled = true;
      fetch(`${createUrl}/${workspace.dataset.maskedAttachmentId}/encrypted_download`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Accept': 'application/pdf',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ password })
      })
        .then((response) => {
          if (!response.ok) throw new Error('Download failed');
          return response.blob();
        })
        .then((pdfBlob) => {
          downloadBlob(
            pdfBlob,
            workspace.dataset.maskedAttachmentName ? `encrypted_${workspace.dataset.maskedAttachmentName}` : 'encrypted_masked_attachment.pdf'
          );
        })
        .catch(() => {
          setStatus('Download error');
        })
        .finally(() => {
          if (passwordSubmitButton) passwordSubmitButton.disabled = false;
          downloadButton.disabled = false;
        });
    };

    if (passwordForm) {
      passwordForm.addEventListener('submit', (event) => {
        event.preventDefault();
        const password = passwordInput ? passwordInput.value.trim() : '';
        if (!password) {
          setHidden(passwordError, false);
          if (passwordInput) passwordInput.focus();
          return;
        }

        hideModal(passwordModal);
        downloadEncryptedPdf(password);
      });
    }

    passwordCloseButtons.forEach((button) => {
      button.addEventListener('click', () => hideModal(passwordModal));
    });

    shareCloseButtons.forEach((button) => {
      button.addEventListener('click', () => hideModal(shareModal));
    });

    bindCopyButton(shareCopyButton, shareInput, (text) => setShareStatus(text));

    window.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        hideModal(passwordModal);
        hideModal(shareModal);
      }
    });

    window.addEventListener('beforeunload', () => {
      if (currentPdfUrl) URL.revokeObjectURL(currentPdfUrl);
    });

    updatePreview();
  };

  const bindMaskedVersionsPage = () => {
    const downloadButtons = Array.from(document.querySelectorAll('[data-version-download-button]'));
    const passwordModal = document.querySelector('[data-version-password-modal]');
    const passwordForm = document.querySelector('[data-version-password-form]');
    const passwordInput = document.querySelector('[data-version-password-input]');
    const passwordError = document.querySelector('[data-version-password-error]');
    const passwordSubmitButton = document.querySelector('[data-version-password-submit-button]');
    const closeButtons = Array.from(document.querySelectorAll('[data-version-password-modal-close]'));
    const shareButtons = Array.from(document.querySelectorAll('[data-version-share-button]'));
    const shareModal = document.querySelector('[data-share-link-modal]');
    const shareInput = document.querySelector('[data-share-link-input]');
    const shareStatus = document.querySelector('[data-share-link-status]');
    const copyButton = document.querySelector('[data-share-link-copy-button]');
    const shareCloseButtons = Array.from(document.querySelectorAll('[data-share-link-modal-close]'));

    let activeDownloadUrl = '';
    let activeDownloadFilename = 'encrypted_masked_attachment.pdf';

    const setShareStatus = (text, failed = false) => {
      if (!shareStatus) return;

      shareStatus.textContent = text;
      shareStatus.hidden = false;
      shareStatus.classList.toggle('is-error', failed);
    };

    const showPasswordModal = (button) => {
      activeDownloadUrl = button.dataset.downloadUrl || '';
      activeDownloadFilename = button.dataset.downloadFilename || activeDownloadFilename;
      setHidden(passwordError, true);
      if (passwordInput) passwordInput.value = '';
      showModal(passwordModal, passwordInput);
    };

    const showShareModal = (shareUrl) => {
      if (!shareModal || !shareInput) return;

      shareInput.value = shareUrl;
      setHidden(shareStatus, true);
      showModal(shareModal, shareInput);
      window.setTimeout(() => shareInput.select(), 0);
    };

    downloadButtons.forEach((button) => {
      button.addEventListener('click', () => showPasswordModal(button));
    });

    closeButtons.forEach((button) => {
      button.addEventListener('click', () => hideModal(passwordModal));
    });

    if (passwordForm && passwordInput) {
      passwordForm.addEventListener('submit', (event) => {
        event.preventDefault();
        const password = passwordInput.value.trim();
        if (!password) {
          setHidden(passwordError, false);
          return;
        }

        if (passwordSubmitButton) {
          passwordSubmitButton.disabled = true;
          passwordSubmitButton.textContent = 'Downloading...';
        }
        setHidden(passwordError, true);

        fetch(activeDownloadUrl, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Accept': 'application/pdf',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ password })
        })
          .then((response) => {
            if (!response.ok) throw new Error('Download failed');
            return response.blob();
          })
          .then((blob) => {
            downloadBlob(blob, activeDownloadFilename);
            hideModal(passwordModal);
          })
          .catch(() => {
            if (passwordError) {
              passwordError.textContent = 'Could not download this PDF.';
              passwordError.hidden = false;
            }
          })
          .finally(() => {
            if (passwordSubmitButton) {
              passwordSubmitButton.disabled = false;
              passwordSubmitButton.textContent = 'Download encrypted PDF';
            }
          });
      });
    }

    shareButtons.forEach((button) => {
      button.addEventListener('click', () => {
        const shareUrl = button.dataset.shareUrl;
        if (!shareUrl) return;

        button.disabled = true;
        button.textContent = 'Creating...';
        fetch(shareUrl, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: '{}'
        })
          .then((response) => {
            if (!response.ok) throw new Error('Share link failed');
            return response.json();
          })
          .then((payload) => {
            showShareModal(payload.share_url);
          })
          .catch(() => {
            showShareModal('');
            setShareStatus('Could not create a share link.', true);
          })
          .finally(() => {
            button.disabled = false;
            button.textContent = 'Share';
          });
      });
    });

    shareCloseButtons.forEach((button) => {
      button.addEventListener('click', () => hideModal(shareModal));
    });

    bindCopyButton(copyButton, shareInput, (text) => setShareStatus(text));
  };

  onReady(() => {
    bindUploadPicker();
    bindConfirmForms();
    bindScanPage();
    bindMaskedVersionsPage();
  });
})();
