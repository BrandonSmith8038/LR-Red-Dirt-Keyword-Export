# Red Dirt Keyword Export

A Lightroom Classic export plugin that sorts exported photos into one folder per keyword.

```
Base folder\
  Carlos\Carlos-1.jpg
  Carlos\Carlos-2.jpg
  Maria\Maria-1.jpg
  IMG_1234.jpg        <- photos with no ticked keyword keep their original name
```

## Install

1. In Lightroom Classic, open **File → Plug-in Manager**.
2. Click **Add** and choose the `RedDirtKeywordExport.lrplugin` folder.
3. After changing the code, click **Reload Plug-in** in the Plug-in Manager.

## Use

1. Select the photos and open **File → Export**.
2. In the **Export To** dropdown at the top, choose **Red Dirt Keyword Export**.
3. Choose a **Base folder**.
4. Untick any keywords that shouldn't become folders. All of them start ticked.
5. Set file type, size, and metadata as usual, then click **Export**.

## Rules

- A photo with several ticked keywords is copied into each of their folders.
- A photo with no ticked keyword goes into the base folder itself.
- The characters `\ / : * ? " < > |` are removed from folder names.
- Files in a keyword folder are named `<keyword>-<number>`, numbered separately in each folder. Lightroom's File Naming panel is hidden because the plugin does the naming.
- When exporting into a folder that already has `Carlos-1` to `Carlos-3`, numbering continues at `Carlos-4`. Nothing is overwritten.
- The Video, Output Sharpening and Watermarking panels are hidden and always off. Videos in the selection are skipped.
- Photos in the base folder keep their original file name. If that name is already taken, `-2`, `-3`, and so on is added.
- The keyword list comes from the photos selected when the dialog opened. If you change the selection, reopen the dialog.

## Files

| File | Purpose |
|---|---|
| `Info.lua` | Plugin name, ID, and which file provides the export service |
| `ExportServiceProvider.lua` | The dialog panel and the export/copy logic |
| `KeywordUtils.lua` | Plain-Lua helpers: folder name cleanup, unique file names, keyword filtering |
