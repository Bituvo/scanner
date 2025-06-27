# Scanner

This mod adds a machine that can read and write books.

## Usage

Configure the node by setting a digiline channel and send it a table with the format `{command="command", ...}`. The node has eight slots, each of which can hold either one book or one written book.

For each of the following commands, the keys `slot` and `slot1` can be used interchangably.

Whenever data is written to a book, the author of the newly written book will be the one who placed the scanner that made it. This is to avoid forgeries.

### Read

```
{
    command = "read",
    slot = 1 through 8
}
```

A message will be sent back on the same channel containing the contents of the book as a table with fields `title`, `author`, `pages` (number), and `text`.

### Write

```
{
    command = "write",
    title = "title",
    text = "book contents"
}
```

This will overwrite any data already present in that slot. `text` has a limit of 40,000 characters.

### Copy

```
{
    command = "copy",
    slot1 = 1 through 8,
    slot2 = 1 through 8
}
```

If `slot1` is empty or contains an empty book, no data will be written to `slot2`. Otherwise, this will overwrite any data already present in `slot2`.

### Swap

```
{
    command = "swap",
    slot1 = 1 through 8,
    slot2 = 1 through 8
}
```

This will also work if either slot is empty.

### Clear

```
{
    command = "clear",
    slot = 1 through 8
}
```

This will clear any data from a written book and replace it with an empty one.

### Eject

```
{
    command = "eject",
    slot = 1 through 8
}
```

This will eject the book out of the left side. Note that the scanner will accept items from both the left and right.

## License

- Code is licensed under **GNU Lesser General Public License v3.0 (LGPL-3.0)**. See `LICENSE.txt`.
- "book_silhouette.png" is licensed under the **Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA-4.0)**. See `ASSETS_LICENSE.txt`.
