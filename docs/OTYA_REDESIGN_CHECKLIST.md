# OTYA redesign validation checklist

Before merge:

- [ ] Flutter analyze/build passes.
- [ ] Bottom navigation shows Video, Music, Me only.
- [ ] Video and Music playback/queue/mini-player behavior remains intact.
- [ ] Me shows a 3×3 grouped feature grid and profile avatar at top-right.
- [ ] Feature NEW badges do not change tile dimensions and disappear after opening the versioned feature.
- [ ] Existing media establishes an unseen baseline; later scans may mark new media locally.
- [ ] No media filenames or local library lists are uploaded for NEW-state tracking.
- [ ] Transfer remains available without sign-in/cloud where the underlying local engine supports it.
- [ ] Settings, themes and media scanning remain usable offline.
