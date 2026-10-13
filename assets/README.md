# assets/

Generated art and imported assets. This folder is where the art-director agent
copies final images. The authoritative prompts live in
`../docs/art/prompts/`.

## Layout

```
assets/
├── ships/
│   ├── acero/
│   ├── vinculados/
│   └── marea-libre/
├── heroes/
├── environments/
├── ui/
└── splash/
```

## Rules

- Follow the layout above; add subfolders as needed and document them here.
- File names are `snake_case` and prefixed by faction where relevant
  (e.g. `acero_corvette.png`).
- Final images may be committed; intermediate/scratch images should not.
- Every committed image must have a matching row in its prompt registry asset
  log under `docs/art/prompts/`.
