defmodule BeamFlowWeb.ErrorJSONTest do
  use BeamFlowWeb.ConnCase, async: true

  @tag :unit
  test "renders 404" do
    assert BeamFlowWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  @tag :unit
  test "renders 500" do
    assert BeamFlowWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
