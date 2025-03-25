defmodule BeamFlowWeb.Components.MarkdownEditorComponentTest do
  use BeamFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  alias BeamFlowWeb.Components.MarkdownEditorComponent

  @tag :unit
  test "markdown_to_html/1 converts markdown to HTML properly" do
    html =
      render_component(MarkdownEditorComponent, %{
        id: "test-editor",
        field_name: "content",
        value: "# Test Heading\n\nParagraph with **bold** and *italic* text."
      })

    # Check rendered HTML in preview area
    assert html =~
             "<div class=\"border border-gray-300 rounded-b-md p-4 prose max-w-none h-64 overflow-y-auto\">"

    assert html =~ "<h1>\nTest Heading</h1>"
    assert html =~ "<strong>bold</strong>"
    assert html =~ "<em>italic</em>"
  end

  @tag :unit
  test "sanitizes HTML in markdown content" do
    html =
      render_component(MarkdownEditorComponent, %{
        id: "test-editor",
        field_name: "content",
        value: "<script>alert('xss')</script>\n\nSafe paragraph."
      })

    refute html =~ "<script>"
    assert html =~ "Safe paragraph"
  end

  @tag :unit
  test "preview toggle functionality" do
    # Test initial visibility states
    assert render_component(MarkdownEditorComponent, %{
             id: "test-editor",
             field_name: "content",
             value: "Test",
             show_preview: true
           }) =~ "class=\"block md:block\""

    assert render_component(MarkdownEditorComponent, %{
             id: "test-editor",
             field_name: "content",
             value: "Test",
             show_preview: false
           }) =~ "class=\"hidden md:block\""
  end

  @tag :unit
  test "handles empty content gracefully" do
    # Test empty string
    html_empty =
      render_component(MarkdownEditorComponent, %{
        id: "test-editor",
        field_name: "content",
        value: ""
      })

    assert html_empty =~
             "<div class=\"border border-gray-300 rounded-b-md p-4 prose max-w-none h-64 overflow-y-auto\">"

    # Test nil
    html_nil =
      render_component(MarkdownEditorComponent, %{
        id: "test-editor",
        field_name: "content",
        value: nil
      })

    assert html_nil =~
             "<div class=\"border border-gray-300 rounded-b-md p-4 prose max-w-none h-64 overflow-y-auto\">"
  end

  @tag :performance
  test "handles large content efficiently" do
    # Generate 1000 lines of markdown
    large_content = Enum.map_join(1..1000, "\n", fn i -> "Line #{i} with **bold** text." end)

    {time, result} =
      :timer.tc(fn ->
        render_component(MarkdownEditorComponent, %{
          id: "test-editor",
          field_name: "content",
          value: large_content
        })
      end)

    # Performance assertions
    assert time < 5_000_000
    assert result =~ "Line 1 with"
    assert result =~ "Line 1000 with"
  end
end
