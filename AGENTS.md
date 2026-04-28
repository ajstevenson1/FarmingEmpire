1. Code Context
- Project is a Roblox game using Rojo + VS Code
- Only code files are visible
- Assume all mentioned Studio objects exist
- If code requires a new object, explicitly state what must be created in Studio

2. Design First
- Always design systems before writing code
- Do not write code until design is confirmed

3. Modularity
- Systems must be modular and isolated
- Avoid tightly coupled logic
- Prefer small, single-responsibility modules

4. Typing
- Use Luau strict typing everywhere
- Define types for all major systems and data structures
- Avoid `any` unless absolutely necessary

5. Scalability
- Systems must support future expansion (more crops, buildings, upgrades)
- No hardcoding values that should be configurable

6. Data & State
- Separate game state from logic
- No hidden state inside random scripts
- Use clear data flow (inputs → processing → outputs)

7. Performance
- Avoid unnecessary loops and expensive operations
- Design with multiplayer scaling in mind

8. Clarity
- Code must be readable and structured
- Use clear naming conventions
- No messy or “quick fix” logic