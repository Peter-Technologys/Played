# NEW media integration

`NewMediaTracker` is already reconciled by `MediaScannerService.scanAll()`.

UI integration must be non-invasive:

- Place `MediaNewIndicator(item: item)` beside an existing media title or within an existing thumbnail `Stack`.
- Before opening/playing a media item, call `NewMediaTracker.instance.markSeen(item)`.
- Do not change list dimensions, item extents, queue ordering, thumbnail generation or playback routes just to show NEW.
- Received media is not a separate library. Playable video flows into Video; playable audio flows into Music.
- The initial library scan is a baseline and does not mark an existing library as new.
