using System.Collections;
using System.Diagnostics;
using System.Text.RegularExpressions;

namespace eLlama;

public class MainForm : Form
{
    private string ModelsRootDirectory => AppSettings.Instance.ModelsDirectory;
    private string LlamaCliPath => AppSettings.Instance.LlamaCliPath;

    private TextBox txtSearch = null!;
    private CheckBox chkHideProjectors = null!;
    private Button btnRefresh = null!;
    private Button btnRun = null!;
    private Button btnOpenFolder = null!;
    private ListView lvModels = null!;
    private ToolStripStatusLabel lblCount = null!;
    private ToolStripStatusLabel lblBackendStatus = null!;
    private Button btnSettings = null!;
    private ToolStripControlHost hostSettings = null!;

    private readonly List<ModelInfo> allModels = new();
    private ListViewColumnSorter columnSorter = null!;

    public MainForm()
    {
        InitializeComponent();
        LoadModels();
        UpdateBackendStatus();
    }

    private void InitializeComponent()
    {
        Text = "eLlama";
        Size = new Size(1080, 640);
        MinimumSize = new Size(850, 480);
        StartPosition = FormStartPosition.CenterScreen;
        Font = SystemFonts.DefaultFont;

        try
        {
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;
        }
        catch
        {
            Icon = SystemIcons.Application;
        }

        // Top Panel
        var topPanel = new Panel
        {
            Dock = DockStyle.Top,
            Height = 48,
            Padding = new Padding(10, 8, 10, 8)
        };

        var lblSearch = new Label
        {
            Text = "Search:",
            AutoSize = true,
            Location = new Point(10, 15)
        };

        txtSearch = new TextBox
        {
            Location = new Point(62, 12),
            Width = 240,
            PlaceholderText = "Filter models, publisher, quant..."
        };
        txtSearch.TextChanged += (s, e) => FilterModels();

        chkHideProjectors = new CheckBox
        {
            Text = "Hide Projectors (mmproj)",
            AutoSize = true,
            Checked = AppSettings.Instance.HideProjectors,
            Location = new Point(315, 14)
        };
        chkHideProjectors.CheckedChanged += (s, e) =>
        {
            AppSettings.Instance.HideProjectors = chkHideProjectors.Checked;
            AppSettings.Instance.Save();
            FilterModels();
        };

        btnRefresh = new Button
        {
            Text = "Refresh",
            Location = new Point(500, 10),
            Width = 75,
            Height = 28
        };
        btnRefresh.Click += (s, e) => LoadModels();

        btnRun = new Button
        {
            Text = "Run Model",
            Location = new Point(585, 10),
            Width = 110,
            Height = 28,
            Enabled = false,
            Font = new Font(Font, FontStyle.Bold)
        };
        btnRun.Click += (s, e) => RunSelectedModel();

        btnOpenFolder = new Button
        {
            Text = "Open Folder",
            Location = new Point(705, 10),
            Width = 95,
            Height = 28,
            Enabled = false
        };
        btnOpenFolder.Click += (s, e) => OpenSelectedFolder();

        topPanel.Controls.AddRange(new Control[]
        {
            lblSearch,
            txtSearch,
            chkHideProjectors,
            btnRefresh,
            btnRun,
            btnOpenFolder
        });

        // ListView
        lvModels = new ListView
        {
            Dock = DockStyle.Fill,
            View = View.Details,
            FullRowSelect = true,
            GridLines = true,
            MultiSelect = false,
            HideSelection = false
        };

        columnSorter = new ListViewColumnSorter();
        lvModels.ListViewItemSorter = columnSorter;

        lvModels.Columns.Add("Model Name", 280);
        lvModels.Columns.Add("Quant", 90);
        lvModels.Columns.Add("Size", 90, HorizontalAlignment.Right);
        lvModels.Columns.Add("Publisher", 140);
        lvModels.Columns.Add("Filename", 350);

        lvModels.SelectedIndexChanged += (s, e) => UpdateSelectedButtons();
        lvModels.DoubleClick += (s, e) => RunSelectedModel();
        lvModels.KeyDown += (s, e) =>
        {
            if (e.KeyCode == Keys.Enter)
            {
                e.Handled = true;
                RunSelectedModel();
            }
        };

        lvModels.ColumnClick += (s, e) =>
        {
            if (e.Column == columnSorter.SortColumn)
            {
                columnSorter.Order = columnSorter.Order == SortOrder.Ascending
                    ? SortOrder.Descending
                    : SortOrder.Ascending;
            }
            else
            {
                columnSorter.SortColumn = e.Column;
                columnSorter.Order = SortOrder.Ascending;
            }
            lvModels.Sort();
        };

        // Context Menu (no emojis)
        var contextMenu = new ContextMenuStrip();
        var menuRun = new ToolStripMenuItem("Run Model", null, (s, e) => RunSelectedModel())
        {
            Font = new Font(Font, FontStyle.Bold)
        };
        var menuCopyCmd = new ToolStripMenuItem("Copy Run Command", null, (s, e) => CopyRunCommand());
        var menuCopyPath = new ToolStripMenuItem("Copy File Path", null, (s, e) => CopyFilePath());
        var menuOpenFolder = new ToolStripMenuItem("Open in File Explorer", null, (s, e) => OpenSelectedFolder());
        var menuRefresh = new ToolStripMenuItem("Refresh List", null, (s, e) => LoadModels());

        contextMenu.Items.AddRange(new ToolStripItem[]
        {
            menuRun,
            new ToolStripSeparator(),
            menuCopyCmd,
            menuCopyPath,
            new ToolStripSeparator(),
            menuOpenFolder,
            menuRefresh
        });
        lvModels.ContextMenuStrip = contextMenu;

        // Status Strip
        var statusStrip = new StatusStrip();
        lblCount = new ToolStripStatusLabel
        {
            Text = "Loading models...",
            Spring = true,
            TextAlign = ContentAlignment.MiddleLeft
        };
        lblBackendStatus = new ToolStripStatusLabel
        {
            Text = "llama.cpp: Checking...",
            Alignment = ToolStripItemAlignment.Right
        };

        // Settings button
        btnSettings = new Button
        {
            Text = "Settings",
            Size = new Size(72, 24),
            AutoSize = false,
            FlatStyle = FlatStyle.System,
            Cursor = Cursors.Hand
        };
        btnSettings.Click += (s, e) => OpenSettings();

        hostSettings = new ToolStripControlHost(btnSettings)
        {
            AutoSize = false,
            Size = new Size(72, 24),
            Alignment = ToolStripItemAlignment.Right,
            Margin = new Padding(6, 2, 8, 2)
        };

        statusStrip.Items.AddRange(new ToolStripItem[] { lblCount, lblBackendStatus, hostSettings });

        Controls.Add(lvModels);
        Controls.Add(topPanel);
        Controls.Add(statusStrip);
    }

    private void OpenSettings()
    {
        using var settingsForm = new SettingsForm(() =>
        {
            chkHideProjectors.Checked = AppSettings.Instance.HideProjectors;
            UpdateBackendStatus();
            LoadModels();
        });
        settingsForm.ShowDialog(this);
    }

    private void UpdateBackendStatus()
    {
        if (File.Exists(LlamaCliPath))
        {
            lblBackendStatus.Text = "llama.cpp: Ready";
            lblBackendStatus.ForeColor = Color.DarkGreen;
        }
        else
        {
            lblBackendStatus.Text = "llama.cpp: Not Found";
            lblBackendStatus.ForeColor = Color.Red;
        }
    }

    private void LoadModels()
    {
        allModels.Clear();

        if (!Directory.Exists(ModelsRootDirectory))
        {
            MessageBox.Show($"Models directory not found: {ModelsRootDirectory}", "Directory Not Found", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        try
        {
            var files = Directory.GetFiles(ModelsRootDirectory, "*.gguf", SearchOption.AllDirectories);
            foreach (var file in files)
            {
                var fi = new FileInfo(file);
                allModels.Add(ParseModel(fi));
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Error reading models:\n{ex.Message}", "Scan Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        FilterModels();
        UpdateSelectedButtons();
        UpdateBackendStatus();
    }

    private ModelInfo ParseModel(FileInfo fi)
    {
        string filename = fi.Name;
        string relative = Path.GetRelativePath(ModelsRootDirectory, fi.FullName);
        string[] parts = relative.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string publisher = parts.Length > 1 ? parts[0] : "Local";

        bool isProjector = filename.StartsWith("mmproj", StringComparison.OrdinalIgnoreCase);

        string quant = "Unknown";
        var quantMatch = Regex.Match(filename, @"(?:[._-])(UD-Q[0-9]_[A-Z0-9_]+|Q[0-9]_[A-Z0-9_]+|IQ[0-9]_[A-Z0-9_]+|Q[0-9]_[0-9]|BF16|F16|F32|QAT-Q[0-9]_[0-9])(?:[._-]|\.gguf)", RegexOptions.IgnoreCase);
        if (quantMatch.Success && quantMatch.Groups.Count > 1)
        {
            quant = quantMatch.Groups[1].Value.TrimStart('.', '_', '-');
        }

        string baseName = Path.GetFileNameWithoutExtension(filename);
        if (quantMatch.Success)
        {
            int idx = baseName.IndexOf(quantMatch.Groups[1].Value, StringComparison.OrdinalIgnoreCase);
            if (idx > 0)
            {
                baseName = baseName.Substring(0, idx).TrimEnd('.', '_', '-');
            }
        }

        if (isProjector)
        {
            baseName = "[Vision Projector] " + baseName.Replace("mmproj-", "").TrimStart('.', '_', '-');
        }

        return new ModelInfo
        {
            FilePath = fi.FullName,
            FileName = filename,
            ModelName = baseName,
            Publisher = publisher,
            Quant = quant,
            SizeBytes = fi.Length,
            IsProjector = isProjector
        };
    }

    private void FilterModels()
    {
        string filter = txtSearch.Text.Trim();
        bool hideProjectors = chkHideProjectors.Checked;

        lvModels.BeginUpdate();
        lvModels.Items.Clear();

        long visibleBytes = 0;
        int visibleCount = 0;

        foreach (var model in allModels)
        {
            if (hideProjectors && model.IsProjector)
            {
                continue;
            }

            if (!string.IsNullOrEmpty(filter))
            {
                bool match = model.ModelName.Contains(filter, StringComparison.OrdinalIgnoreCase) ||
                             model.Publisher.Contains(filter, StringComparison.OrdinalIgnoreCase) ||
                             model.Quant.Contains(filter, StringComparison.OrdinalIgnoreCase) ||
                             model.FileName.Contains(filter, StringComparison.OrdinalIgnoreCase);

                if (!match) continue;
            }

            var item = new ListViewItem(model.ModelName);
            item.SubItems.Add(model.Quant);
            item.SubItems.Add(FormatBytes(model.SizeBytes));
            item.SubItems.Add(model.Publisher);
            item.SubItems.Add(model.FileName);
            item.Tag = model;

            if (model.IsProjector)
            {
                item.ForeColor = SystemColors.GrayText;
            }

            lvModels.Items.Add(item);
            visibleBytes += model.SizeBytes;
            visibleCount++;
        }

        lvModels.EndUpdate();

        lblCount.Text = $"Showing {visibleCount} of {allModels.Count} models ({FormatBytes(visibleBytes)})";
    }

    private ModelInfo? GetSelectedModel()
    {
        if (lvModels.SelectedItems.Count == 0) return null;
        return lvModels.SelectedItems[0].Tag as ModelInfo;
    }

    private void UpdateSelectedButtons()
    {
        var model = GetSelectedModel();
        if (model == null)
        {
            btnRun.Enabled = false;
            btnOpenFolder.Enabled = false;
            btnRun.Text = "Run Model";
            return;
        }

        btnOpenFolder.Enabled = true;

        if (model.IsProjector)
        {
            btnRun.Enabled = false;
            btnRun.Text = "Vision Projector";
            return;
        }

        btnRun.Enabled = true;
        btnRun.Text = "Run Model";
    }

    private void RunSelectedModel()
    {
        var model = GetSelectedModel();
        if (model == null) return;

        if (model.IsProjector)
        {
            MessageBox.Show(
                "This file is a vision projector (mmproj), not a standalone language model.\n\nPlease select an LLM model to run.",
                "Vision Projector",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );
            return;
        }

        if (!File.Exists(LlamaCliPath))
        {
            var res = MessageBox.Show(
                $"llama-cli.exe was not found at:\n{LlamaCliPath}\n\nWould you like to configure the path in Settings?",
                "llama.cpp Not Found",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning
            );
            if (res == DialogResult.Yes)
            {
                OpenSettings();
            }
            return;
        }

        string cliArgs = BuildLlamaArgs(model);

        var psi = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = $"/k \"title {model.ModelName} & \"\"{LlamaCliPath}\"\" {cliArgs}\"",
            UseShellExecute = true
        };

        try
        {
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to launch model:\n{ex.Message}", "Launch Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static string BuildLlamaArgs(ModelInfo model)
    {
        var s = AppSettings.Instance;
        var args = new List<string>
        {
            $"-m \"{model.FilePath}\"",
            $"-t {s.Threads}",
            $"-c {s.ContextSize}"
        };

        if (s.GpuLayers > 0) args.Add($"-ngl {s.GpuLayers}");
        if (s.BatchSize != 512) args.Add($"-b {s.BatchSize}");
        if (s.UBatchSize != 512) args.Add($"-ub {s.UBatchSize}");

        if (!string.Equals(s.CacheTypeK, "f16", StringComparison.OrdinalIgnoreCase))
            args.Add($"-ctk {s.CacheTypeK}");
        if (!string.Equals(s.CacheTypeV, "f16", StringComparison.OrdinalIgnoreCase))
            args.Add($"-ctv {s.CacheTypeV}");

        if (!string.Equals(s.FlashAttention, "auto", StringComparison.OrdinalIgnoreCase))
            args.Add($"-fa {s.FlashAttention}");

        if (s.MLock) args.Add("--mlock");
        if (s.NoMMap) args.Add("--no-mmap");

        // Sampling
        args.Add($"--temp {s.Temperature.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)}");
        args.Add($"--top-p {s.TopP.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)}");
        args.Add($"--top-k {s.TopK}");
        args.Add($"--min-p {s.MinP.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)}");
        args.Add($"--repeat-penalty {s.RepeatPenalty.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)}");
        if (s.RepeatLastN != 64) args.Add($"--repeat-last-n {s.RepeatLastN}");
        if (s.MaxTokens > 0) args.Add($"-n {s.MaxTokens}");

        return string.Join(" ", args);
    }

    private void OpenSelectedFolder()
    {
        var model = GetSelectedModel();
        if (model == null) return;

        if (File.Exists(model.FilePath))
        {
            Process.Start("explorer.exe", $"/select,\"{model.FilePath}\"");
        }
        else
        {
            Process.Start("explorer.exe", ModelsRootDirectory);
        }
    }

    private void CopyRunCommand()
    {
        var model = GetSelectedModel();
        if (model == null) return;

        string cliArgs = BuildLlamaArgs(model);
        string cmd = $"& \"{LlamaCliPath}\" {cliArgs}";
        Clipboard.SetText(cmd);
    }

    private void CopyFilePath()
    {
        var model = GetSelectedModel();
        if (model == null) return;

        Clipboard.SetText(model.FilePath);
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes >= 1024L * 1024L * 1024L)
        {
            return (bytes / (1024.0 * 1024.0 * 1024.0)).ToString("F2") + " GB";
        }
        if (bytes >= 1024L * 1024L)
        {
            return (bytes / (1024.0 * 1024.0)).ToString("F2") + " MB";
        }
        return (bytes / 1024.0).ToString("F2") + " KB";
    }
}

public class ModelInfo
{
    public required string FilePath { get; init; }
    public required string FileName { get; init; }
    public required string ModelName { get; init; }
    public required string Publisher { get; init; }
    public required string Quant { get; init; }
    public required long SizeBytes { get; init; }
    public required bool IsProjector { get; init; }
}

public class ListViewColumnSorter : IComparer
{
    public int SortColumn { get; set; } = 0;
    public SortOrder Order { get; set; } = SortOrder.Ascending;

    public int Compare(object? x, object? y)
    {
        if (x is not ListViewItem itemX || y is not ListViewItem itemY)
            return 0;

        int result;
        if (SortColumn == 2) // Size column (index 2 now: Model Name=0, Quant=1, Size=2, Publisher=3, Filename=4)
        {
            long sizeX = (itemX.Tag as ModelInfo)?.SizeBytes ?? 0;
            long sizeY = (itemY.Tag as ModelInfo)?.SizeBytes ?? 0;
            result = sizeX.CompareTo(sizeY);
        }
        else
        {
            string textX = itemX.SubItems.Count > SortColumn ? itemX.SubItems[SortColumn].Text : "";
            string textY = itemY.SubItems.Count > SortColumn ? itemY.SubItems[SortColumn].Text : "";
            result = string.Compare(textX, textY, StringComparison.OrdinalIgnoreCase);
        }

        return Order == SortOrder.Descending ? -result : result;
    }
}
