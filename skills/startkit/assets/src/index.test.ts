import { expect, test } from "vitest";

import { greet } from "./index.ts";

test("greet builds a greeting", () => {
  expect(greet("World")).toBe("Hello, World!");
});
