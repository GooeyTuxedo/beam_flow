// assets/js/hooks/markdown_editor_hooks.js
const MarkdownEditorHooks = {
  MarkdownInput: {
    mounted() {
      this.el.addEventListener("input", (e) => {
        this.pushEventTo(this.el.dataset.phxTarget, "content-changed", {
          value: e.target.value,
        });
      });
    },
  },

  MarkdownEditor: {
    mounted() {
      // Get reference to the textarea
      this.textarea = this.el.querySelector("textarea");

      // Track if there are unsaved changes
      this.hasUnsavedChanges = false;

      // Add event listener for input to detect changes
      this.textarea.addEventListener("input", () => {
        this.hasUnsavedChanges = true;
      });

      // Listen for markdown format events
      this.handleEvent("markdown-format", ({ format }) => {
        this.formatMarkdown(format);
      });

      // Add event listener for beforeunload to prompt user if there are unsaved changes
      window.addEventListener("beforeunload", (e) => {
        if (this.hasUnsavedChanges) {
          e.preventDefault();
          e.returnValue = "";
        }
      });

      // Reset unsaved changes flag when saving
      this.handleEvent("changes-saved", () => {
        this.hasUnsavedChanges = false;
      });
    },

    formatMarkdown(format) {
      const textarea = this.textarea;
      const selStart = textarea.selectionStart;
      const selEnd = textarea.selectionEnd;
      const text = textarea.value;
      const selection = text.substring(selStart, selEnd);

      let replacement = "";
      let cursorOffset = 0;

      switch (format) {
        case "bold":
          replacement = `**${selection}**`;
          if (!selection) cursorOffset = 2;
          break;
        case "italic":
          replacement = `*${selection}*`;
          if (!selection) cursorOffset = 1;
          break;
        case "heading":
          replacement = `\n## ${selection}`;
          if (!selection) cursorOffset = 3;
          break;
        case "link":
          replacement = selection ? `[${selection}](url)` : `[text](url)`;
          if (selection) {
            cursorOffset = 3;
          } else {
            cursorOffset = 1;
          }
          break;
        case "image":
          replacement = `![${selection || "alt text"}](image-url)`;
          if (!selection) cursorOffset = 10;
          break;
        case "code":
          replacement = selection.includes("\n")
            ? `\n\`\`\`\n${selection}\n\`\`\`\n`
            : `\`${selection}\``;
          if (!selection) cursorOffset = 1;
          break;
        case "list":
          // Split selection by lines
          if (selection) {
            const lines = selection.split("\n");
            replacement = lines.map((line) => `- ${line}`).join("\n");
          } else {
            replacement = "- ";
          }
          break;
      }

      // Insert the replacement text
      textarea.focus();
      textarea.setRangeText(replacement, selStart, selEnd);

      // Set the cursor position
      if (!selection) {
        textarea.selectionStart = textarea.selectionEnd =
          selStart + cursorOffset;
      } else {
        textarea.selectionStart = selStart;
        textarea.selectionEnd = selStart + replacement.length;
      }

      // Trigger input event to update preview
      textarea.dispatchEvent(new Event("input", { bubbles: true }));
    },
  },
};

export default MarkdownEditorHooks;
