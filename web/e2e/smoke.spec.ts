import { expect, test } from "@playwright/test";

test("homepage smoke", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle(/YiACAD Web/i);
  await expect(page.getByRole("heading", { name: "Project dashboard" })).toBeVisible();
  await expect(page.getByText("Git-based EDA platform")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Core platform" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Infra VPS" })).toBeVisible();
});