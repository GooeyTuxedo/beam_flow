defmodule BeamFlowWeb.ErrorHTMLTest do
  use BeamFlowWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  @tag :unit
  test "renders 404.html" do
    assert render_to_string(BeamFlowWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  @tag :unit
  test "renders 500.html" do
    assert render_to_string(BeamFlowWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
