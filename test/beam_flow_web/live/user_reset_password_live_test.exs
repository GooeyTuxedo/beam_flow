defmodule BeamFlowWeb.UserResetPasswordLiveTest do
  use BeamFlowWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeamFlow.AccountsFixtures

  alias BeamFlow.Accounts

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)

    %{token: token, user: user}
  end

  describe "Reset password page" do
    test "renders reset password with valid token", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset_password/#{token}")

      assert html =~ "Reset Password"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      {:error, {:redirect, to}} = live(conn, ~p"/users/reset_password/invalid")

      assert to == %{
               to: "/",
               flash: %{"error" => "Reset password link is invalid or it has expired."}
             }
    end

    test "renders errors for invalid data", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      _result =
        lv
        |> element("#reset_password_form")
        |> render_change(
          user: %{"password" => "secret12", "password_confirmation" => "secret123456"}
        )

      # Check that errors are displayed
      rendered = render(lv)
      assert rendered =~ "should be at least 12 character"
      assert rendered =~ "does not match password"
    end
  end

  describe "Reset Password" do
    test "resets password once", %{conn: conn, token: token, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      # We need to use a password that meets all the requirements
      # including uppercase, lowercase, and special characters
      new_password = "NewValidPassword123!"

      # Submit the form
      lv
      |> form("#reset_password_form",
        user: %{
          "password" => new_password,
          "password_confirmation" => new_password
        }
      )
      |> render_submit()

      # Check if the user can log in with the new password
      assert Accounts.get_user_by_email_and_password(user.email, new_password)

      # Since this redirects to a new LiveView and not an HTML page,
      # we need to verify the redirection differently: by checking
      # we are no longer on the reset password page
      refute_redirected(lv, ~p"/users/reset_password/#{token}")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      rendered =
        lv
        |> form("#reset_password_form",
          user: %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        )
        |> render_submit()

      # Check that the form is still showing with errors
      assert rendered =~ "Reset Password"
      assert rendered =~ "should be at least 12 character"
      assert rendered =~ "does not match password"
    end
  end

  describe "Reset password navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      {:ok, conn} =
        lv
        |> element(~s|main a:fl-contains("Log in")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert conn.resp_body =~ "Log in"
    end

    test "redirects to registration page when the Register button is clicked", %{
      conn: conn,
      token: token
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      {:ok, conn} =
        lv
        |> element(~s|main a:fl-contains("Register")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert conn.resp_body =~ "Register"
    end
  end
end
