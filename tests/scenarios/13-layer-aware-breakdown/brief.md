# Brief: Notes feature

Add a notes feature to the backend. A signed-in user can list their own notes and
create a note. A note has a title and a body. On create, generate a URL-safe slug
from the title.

In scope:
- List a user's notes.
- Create a note (title + body); derive a URL-safe slug from the title on create.

Out of scope:
- Editing or deleting a note.
- Any web/UI surface — this is the backend only.
