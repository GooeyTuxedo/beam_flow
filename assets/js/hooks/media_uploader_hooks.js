const MediaUploader = {
  mounted() {
    const dropZone = this.el.querySelector("[phx-drop-target]");
    if (!dropZone) return;

    const uploadInput = document.getElementById(
      this.el.querySelector('input[type="file"]').id,
    );

    dropZone.addEventListener("dragover", (e) => {
      e.preventDefault();
      dropZone.classList.add("bg-indigo-50");
    });

    dropZone.addEventListener("dragleave", () => {
      dropZone.classList.remove("bg-indigo-50");
    });

    dropZone.addEventListener("drop", (e) => {
      e.preventDefault();
      dropZone.classList.remove("bg-indigo-50");

      const files = e.dataTransfer.files;
      if (files.length > 0) {
        // Convert FileList to Array and append to the LiveView UploadEntry
        const dataTransfer = new DataTransfer();
        Array.from(files).forEach((file) => dataTransfer.items.add(file));
        uploadInput.files = dataTransfer.files;

        // Trigger change event to notify LiveView
        uploadInput.dispatchEvent(new Event("change", { bubbles: true }));
      }
    });
  },
};

export default { MediaUploader };
