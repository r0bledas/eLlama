using System.Diagnostics;
using System.IO.Compression;
using System.Text;
using System.Text.Json;

namespace eLlama;

public class SettingsForm : Form
{
    // General Tab
    private TextBox txtDirectory = null!;
    private TextBox txtLlamaCli = null!;
    private CheckBox chkHideProjectors = null!;
    private ComboBox cmbExportFormat = null!;
    private Button btnDownloadLlama = null!;

    // Hardware & Compute
    private NumericUpDown numThreads = null!;
    private NumericUpDown numGpuLayers = null!;
    private ComboBox cmbContextSize = null!;
    private NumericUpDown numCustomContext = null!;
    private ComboBox cmbBatchSize = null!;
    private ComboBox cmbUBatchSize = null!;

    // KV Cache & Memory
    private ComboBox cmbCacheK = null!;
    private ComboBox cmbCacheV = null!;
    private ComboBox cmbFlashAttn = null!;
    private CheckBox chkMlock = null!;
    private CheckBox chkNoMMap = null!;

    // Sampling & Generation
    private NumericUpDown numTemp = null!;
    private NumericUpDown numTopP = null!;
    private NumericUpDown numTopK = null!;
    private NumericUpDown numMinP = null!;
    private NumericUpDown numRepeatPenalty = null!;
    private NumericUpDown numRepeatLastN = null!;
    private ComboBox cmbMaxTokens = null!;

    private readonly List<ModelInfo> currentModels;
    private readonly Action onSettingsSaved;

    public SettingsForm(List<ModelInfo> models, Action onSaved)
    {
        currentModels = models ?? new List<ModelInfo>();
        onSettingsSaved = onSaved;

        InitializeComponent();
        LoadCurrentSettings();
    }

    private void InitializeComponent()
    {
        Text = "Settings";
        Size = new Size(660, 580);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowInTaskbar = false;
        Font = SystemFonts.DefaultFont;

        var tabControl = new TabControl
        {
            Location = new Point(12, 12),
            Size = new Size(620, 480)
        };

        var tabGeneral = new TabPage("General");
        var tabAdvanced = new TabPage("Advanced Inference");
        var tabAbout = new TabPage("About & Credits");

        BuildGeneralTab(tabGeneral);
        BuildAdvancedTab(tabAdvanced);
        BuildAboutTab(tabAbout);

        tabControl.TabPages.Add(tabGeneral);
        tabControl.TabPages.Add(tabAdvanced);
        tabControl.TabPages.Add(tabAbout);

        // Bottom Controls
        var btnReset = new Button
        {
            Text = "Reset Defaults",
            Location = new Point(14, 502),
            Size = new Size(125, 28)
        };
        btnReset.Click += (s, e) => ResetToDefaults();

        var btnSave = new Button
        {
            Text = "Save",
            Location = new Point(440, 502),
            Size = new Size(90, 28),
            DialogResult = DialogResult.OK
        };
        btnSave.Click += (s, e) => SaveSettings();

        var btnCancel = new Button
        {
            Text = "Cancel",
            Location = new Point(542, 502),
            Size = new Size(90, 28),
            DialogResult = DialogResult.Cancel
        };

        Controls.AddRange(new Control[] { tabControl, btnReset, btnSave, btnCancel });

        AcceptButton = btnSave;
        CancelButton = btnCancel;
    }

    private void BuildGeneralTab(TabPage tab)
    {
        // Model Library
        var grpDirectory = new GroupBox
        {
            Text = "Model Library",
            Location = new Point(12, 12),
            Size = new Size(590, 80)
        };

        var lblDir = new Label
        {
            Text = "Models Directory:",
            Location = new Point(14, 22),
            AutoSize = true
        };

        txtDirectory = new TextBox
        {
            Location = new Point(14, 42),
            Size = new Size(465, 24)
        };

        var btnBrowse = new Button
        {
            Text = "Browse...",
            Location = new Point(489, 40),
            Size = new Size(85, 26)
        };
        btnBrowse.Click += (s, e) =>
        {
            string current = AppSettings.ResolvePath(txtDirectory.Text);
            using var fbd = new FolderBrowserDialog
            {
                SelectedPath = Directory.Exists(current) ? current : AppSettings.AppDir
            };
            if (fbd.ShowDialog(this) == DialogResult.OK)
            {
                txtDirectory.Text = AppSettings.ToRelativePath(fbd.SelectedPath);
            }
        };

        grpDirectory.Controls.AddRange(new Control[] { lblDir, txtDirectory, btnBrowse });

        // Backend
        var grpBackend = new GroupBox
        {
            Text = "llama.cpp Backend",
            Location = new Point(12, 98),
            Size = new Size(590, 115)
        };

        var lblLlama = new Label
        {
            Text = "llama-cli.exe Executable Path:",
            Location = new Point(14, 22),
            AutoSize = true
        };

        txtLlamaCli = new TextBox
        {
            Location = new Point(14, 42),
            Size = new Size(465, 24)
        };

        var btnBrowseLlama = new Button
        {
            Text = "Browse...",
            Location = new Point(489, 40),
            Size = new Size(85, 26)
        };
        btnBrowseLlama.Click += (s, e) =>
        {
            string current = AppSettings.ResolvePath(txtLlamaCli.Text);
            string initDir = File.Exists(current) ? Path.GetDirectoryName(current)! : Path.Combine(AppSettings.AppDir, "llama.cpp");
            if (!Directory.Exists(initDir)) initDir = AppSettings.AppDir;

            using var ofd = new OpenFileDialog
            {
                Title = "Select llama-cli.exe",
                Filter = "llama-cli.exe|llama-cli*.exe|All Executables (*.exe)|*.exe",
                InitialDirectory = initDir
            };
            if (ofd.ShowDialog(this) == DialogResult.OK)
            {
                txtLlamaCli.Text = AppSettings.ToRelativePath(ofd.FileName);
            }
        };

        btnDownloadLlama = new Button
        {
            Text = "Download Latest llama.cpp (Vulkan)",
            Location = new Point(14, 74),
            Size = new Size(245, 28)
        };
        btnDownloadLlama.Click += (s, e) => DownloadLlamaCppAsync();

        var lblDownloadHint = new Label
        {
            Text = "Auto-installs hardware-accelerated Vulkan binaries into .\\llama.cpp\\",
            Location = new Point(266, 80),
            AutoSize = true,
            ForeColor = SystemColors.GrayText
        };

        grpBackend.Controls.AddRange(new Control[] { lblLlama, txtLlamaCli, btnBrowseLlama, btnDownloadLlama, lblDownloadHint });

        // Display Preferences
        var grpFilter = new GroupBox
        {
            Text = "Display & Filtering",
            Location = new Point(12, 222),
            Size = new Size(590, 65)
        };

        chkHideProjectors = new CheckBox
        {
            Text = "Hide Vision Projectors (mmproj files) by default",
            Location = new Point(14, 26),
            AutoSize = true
        };

        grpFilter.Controls.Add(chkHideProjectors);

        // Export Model Library
        var grpExport = new GroupBox
        {
            Text = "Export Model Library",
            Location = new Point(12, 295),
            Size = new Size(590, 85)
        };

        var lblExport = new Label
        {
            Text = "Format:",
            Location = new Point(14, 28),
            AutoSize = true
        };

        cmbExportFormat = new ComboBox
        {
            Location = new Point(70, 25),
            Size = new Size(160, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbExportFormat.Items.AddRange(new object[]
        {
            "CSV (*.csv)",
            "JSON (*.json)",
            "Markdown (*.md)",
            "Plain Text (*.txt)"
        });
        cmbExportFormat.SelectedIndex = 0;

        var btnExport = new Button
        {
            Text = "Export Model List...",
            Location = new Point(245, 23),
            Size = new Size(150, 28)
        };
        btnExport.Click += (s, e) => ExportModels();

        var lblExportHint = new Label
        {
            Text = "Export your full local model catalog in CSV, JSON, Markdown, or Plain Text format.",
            Location = new Point(14, 58),
            AutoSize = true,
            ForeColor = SystemColors.GrayText
        };

        grpExport.Controls.AddRange(new Control[] { lblExport, cmbExportFormat, btnExport, lblExportHint });

        tab.Controls.AddRange(new Control[] { grpDirectory, grpBackend, grpFilter, grpExport });
    }

    private void BuildAdvancedTab(TabPage tab)
    {
        // 1. Hardware & Compute
        var grpCompute = new GroupBox
        {
            Text = "Hardware & Compute",
            Location = new Point(12, 10),
            Size = new Size(590, 105)
        };

        var lblThreads = new Label { Text = "CPU Threads (-t):", Location = new Point(14, 26), AutoSize = true };
        numThreads = new NumericUpDown
        {
            Location = new Point(125, 24),
            Size = new Size(60, 24),
            Minimum = 1,
            Maximum = 64,
            Value = 4
        };

        var lblGpu = new Label { Text = "GPU Offload (-ngl):", Location = new Point(205, 26), AutoSize = true };
        numGpuLayers = new NumericUpDown
        {
            Location = new Point(325, 24),
            Size = new Size(60, 24),
            Minimum = 0,
            Maximum = 128,
            Value = 0
        };

        var lblBatch = new Label { Text = "Batch Size (-b):", Location = new Point(410, 26), AutoSize = true };
        cmbBatchSize = new ComboBox
        {
            Location = new Point(500, 23),
            Size = new Size(75, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbBatchSize.Items.AddRange(new object[] { "128", "256", "512", "1024", "2048" });

        var lblCtx = new Label { Text = "Context Size (-c):", Location = new Point(14, 62), AutoSize = true };
        cmbContextSize = new ComboBox
        {
            Location = new Point(125, 59),
            Size = new Size(95, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbContextSize.Items.AddRange(new object[] { "1024", "2048", "4096", "8192", "16384", "32768", "65536", "Custom..." });

        numCustomContext = new NumericUpDown
        {
            Location = new Point(226, 59),
            Size = new Size(80, 24),
            Minimum = 256,
            Maximum = 1048576,
            Increment = 1024,
            Value = 8192,
            Enabled = false
        };

        cmbContextSize.SelectedIndexChanged += (s, e) =>
        {
            string? sel = cmbContextSize.SelectedItem?.ToString();
            if (sel == "Custom...")
            {
                numCustomContext.Enabled = true;
                numCustomContext.Focus();
            }
            else
            {
                numCustomContext.Enabled = false;
                if (int.TryParse(sel, out int presetVal))
                {
                    numCustomContext.Value = Math.Clamp(presetVal, numCustomContext.Minimum, numCustomContext.Maximum);
                }
            }
        };

        var lblUBatch = new Label { Text = "Micro-Batch (-ub):", Location = new Point(325, 62), AutoSize = true };
        cmbUBatchSize = new ComboBox
        {
            Location = new Point(440, 59),
            Size = new Size(75, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbUBatchSize.Items.AddRange(new object[] { "128", "256", "512", "1024" });

        grpCompute.Controls.AddRange(new Control[]
        {
            lblThreads, numThreads,
            lblGpu, numGpuLayers,
            lblBatch, cmbBatchSize,
            lblCtx, cmbContextSize, numCustomContext,
            lblUBatch, cmbUBatchSize
        });

        // 2. KV Cache & Memory
        var grpMemory = new GroupBox
        {
            Text = "KV Cache & Memory Optimization",
            Location = new Point(12, 122),
            Size = new Size(590, 100)
        };

        var lblCacheK = new Label { Text = "Cache K (-ctk):", Location = new Point(14, 26), AutoSize = true };
        cmbCacheK = new ComboBox
        {
            Location = new Point(105, 23),
            Size = new Size(75, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbCacheK.Items.AddRange(new object[] { "f16", "q8_0", "q4_0" });

        var lblCacheV = new Label { Text = "Cache V (-ctv):", Location = new Point(195, 26), AutoSize = true };
        cmbCacheV = new ComboBox
        {
            Location = new Point(285, 23),
            Size = new Size(75, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbCacheV.Items.AddRange(new object[] { "f16", "q8_0", "q4_0" });

        var lblFlash = new Label { Text = "Flash Attn (-fa):", Location = new Point(375, 26), AutoSize = true };
        cmbFlashAttn = new ComboBox
        {
            Location = new Point(475, 23),
            Size = new Size(80, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbFlashAttn.Items.AddRange(new object[] { "auto", "on", "off" });

        chkMlock = new CheckBox
        {
            Text = "Lock in RAM (--mlock)",
            Location = new Point(14, 62),
            AutoSize = true
        };

        chkNoMMap = new CheckBox
        {
            Text = "Disable memory-map (--no-mmap)",
            Location = new Point(200, 62),
            AutoSize = true
        };

        grpMemory.Controls.AddRange(new Control[]
        {
            lblCacheK, cmbCacheK,
            lblCacheV, cmbCacheV,
            lblFlash, cmbFlashAttn,
            chkMlock, chkNoMMap
        });

        // 3. Sampling & Generation
        var grpSampling = new GroupBox
        {
            Text = "Sampling & Generation",
            Location = new Point(12, 230),
            Size = new Size(590, 195)
        };

        var lblTemp = new Label { Text = "Temperature (--temp):", Location = new Point(14, 26), AutoSize = true };
        numTemp = new NumericUpDown
        {
            Location = new Point(150, 24),
            Size = new Size(60, 24),
            DecimalPlaces = 2,
            Increment = 0.05m,
            Minimum = 0.00m,
            Maximum = 2.00m,
            Value = 0.80m
        };

        var lblTopP = new Label { Text = "Top-P (--top-p):", Location = new Point(230, 26), AutoSize = true };
        numTopP = new NumericUpDown
        {
            Location = new Point(330, 24),
            Size = new Size(60, 24),
            DecimalPlaces = 2,
            Increment = 0.05m,
            Minimum = 0.00m,
            Maximum = 1.00m,
            Value = 0.95m
        };

        var lblTopK = new Label { Text = "Top-K (--top-k):", Location = new Point(410, 26), AutoSize = true };
        numTopK = new NumericUpDown
        {
            Location = new Point(515, 24),
            Size = new Size(60, 24),
            Minimum = 0,
            Maximum = 200,
            Value = 40
        };

        var lblMinP = new Label { Text = "Min-P (--min-p):", Location = new Point(14, 66), AutoSize = true };
        numMinP = new NumericUpDown
        {
            Location = new Point(150, 64),
            Size = new Size(60, 24),
            DecimalPlaces = 2,
            Increment = 0.01m,
            Minimum = 0.00m,
            Maximum = 1.00m,
            Value = 0.05m
        };

        var lblRep = new Label { Text = "Repeat Penalty (--repeat-penalty):", Location = new Point(230, 66), AutoSize = true };
        numRepeatPenalty = new NumericUpDown
        {
            Location = new Point(440, 64),
            Size = new Size(60, 24),
            DecimalPlaces = 2,
            Increment = 0.05m,
            Minimum = 1.00m,
            Maximum = 2.00m,
            Value = 1.10m
        };

        var lblRepN = new Label { Text = "Repeat Last N (--repeat-last-n):", Location = new Point(14, 106), AutoSize = true };
        numRepeatLastN = new NumericUpDown
        {
            Location = new Point(200, 104),
            Size = new Size(60, 24),
            Minimum = 0,
            Maximum = 1024,
            Increment = 16,
            Value = 64
        };

        var lblMaxN = new Label { Text = "Max Tokens (-n):", Location = new Point(285, 106), AutoSize = true };
        cmbMaxTokens = new ComboBox
        {
            Location = new Point(395, 104),
            Size = new Size(110, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        cmbMaxTokens.Items.AddRange(new object[] { "Unlimited (-1)", "256", "512", "1024", "2048", "4096" });

        var lblHint = new Label
        {
            Text = "Tip: Lower temperature (0.0-0.3) for coding and logic; higher (0.7-1.0) for creative writing.",
            Location = new Point(14, 150),
            AutoSize = true,
            ForeColor = SystemColors.GrayText
        };

        grpSampling.Controls.AddRange(new Control[]
        {
            lblTemp, numTemp,
            lblTopP, numTopP,
            lblTopK, numTopK,
            lblMinP, numMinP,
            lblRep, numRepeatPenalty,
            lblRepN, numRepeatLastN,
            lblMaxN, cmbMaxTokens,
            lblHint
        });

        tab.Controls.AddRange(new Control[] { grpCompute, grpMemory, grpSampling });
    }

    private void LoadCurrentSettings()
    {
        var s = AppSettings.Instance;

        // General
        txtDirectory.Text = s.ModelsDirectory;
        txtLlamaCli.Text = s.LlamaCliPath;
        chkHideProjectors.Checked = s.HideProjectors;

        // Compute
        numThreads.Value = Math.Clamp(s.Threads, numThreads.Minimum, numThreads.Maximum);
        numGpuLayers.Value = Math.Clamp(s.GpuLayers, numGpuLayers.Minimum, numGpuLayers.Maximum);

        int currentCtx = s.ContextSize > 0 ? s.ContextSize : 8192;
        string ctxStr = currentCtx.ToString();
        int idx = cmbContextSize.Items.IndexOf(ctxStr);
        if (idx >= 0 && ctxStr != "Custom...")
        {
            cmbContextSize.SelectedIndex = idx;
            numCustomContext.Value = Math.Clamp(currentCtx, numCustomContext.Minimum, numCustomContext.Maximum);
            numCustomContext.Enabled = false;
        }
        else
        {
            cmbContextSize.SelectedItem = "Custom...";
            numCustomContext.Value = Math.Clamp(currentCtx, numCustomContext.Minimum, numCustomContext.Maximum);
            numCustomContext.Enabled = true;
        }

        SetCombo(cmbBatchSize, s.BatchSize.ToString());
        SetCombo(cmbUBatchSize, s.UBatchSize.ToString());

        // Memory
        SetCombo(cmbCacheK, s.CacheTypeK);
        SetCombo(cmbCacheV, s.CacheTypeV);
        SetCombo(cmbFlashAttn, s.FlashAttention);
        chkMlock.Checked = s.MLock;
        chkNoMMap.Checked = s.NoMMap;

        // Sampling
        numTemp.Value = (decimal)Math.Clamp(s.Temperature, (double)numTemp.Minimum, (double)numTemp.Maximum);
        numTopP.Value = (decimal)Math.Clamp(s.TopP, (double)numTopP.Minimum, (double)numTopP.Maximum);
        numTopK.Value = Math.Clamp(s.TopK, (int)numTopK.Minimum, (int)numTopK.Maximum);
        numMinP.Value = (decimal)Math.Clamp(s.MinP, (double)numMinP.Minimum, (double)numMinP.Maximum);
        numRepeatPenalty.Value = (decimal)Math.Clamp(s.RepeatPenalty, (double)numRepeatPenalty.Minimum, (double)numRepeatPenalty.Maximum);
        numRepeatLastN.Value = Math.Clamp(s.RepeatLastN, (int)numRepeatLastN.Minimum, (int)numRepeatLastN.Maximum);

        if (s.MaxTokens <= 0)
        {
            cmbMaxTokens.SelectedIndex = 0; // Unlimited (-1)
        }
        else
        {
            SetCombo(cmbMaxTokens, s.MaxTokens.ToString());
        }
    }

    private static void SetCombo(ComboBox cmb, string val)
    {
        int idx = cmb.Items.IndexOf(val);
        if (idx >= 0)
        {
            cmb.SelectedIndex = idx;
        }
        else
        {
            cmb.Items.Add(val);
            cmb.SelectedItem = val;
        }
    }

    private void ResetToDefaults()
    {
        var res = MessageBox.Show(
            "Reset all inference settings to recommended defaults?",
            "Reset Defaults",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question
        );

        if (res != DialogResult.Yes) return;

        numThreads.Value = 4;
        numGpuLayers.Value = 0;
        cmbContextSize.SelectedItem = "8192";
        numCustomContext.Value = 8192;
        numCustomContext.Enabled = false;
        SetCombo(cmbBatchSize, "512");
        SetCombo(cmbUBatchSize, "512");

        SetCombo(cmbCacheK, "f16");
        SetCombo(cmbCacheV, "f16");
        SetCombo(cmbFlashAttn, "auto");
        chkMlock.Checked = false;
        chkNoMMap.Checked = false;

        numTemp.Value = 0.80m;
        numTopP.Value = 0.95m;
        numTopK.Value = 40;
        numMinP.Value = 0.05m;
        numRepeatPenalty.Value = 1.10m;
        numRepeatLastN.Value = 64;
        cmbMaxTokens.SelectedIndex = 0;
    }

    private void SaveSettings()
    {
        var s = AppSettings.Instance;

        string newDir = txtDirectory.Text.Trim();
        if (!string.IsNullOrEmpty(newDir))
        {
            s.ModelsDirectory = AppSettings.ToRelativePath(newDir);
        }

        string newLlamaCli = txtLlamaCli.Text.Trim();
        if (!string.IsNullOrEmpty(newLlamaCli))
        {
            s.LlamaCliPath = AppSettings.ToRelativePath(newLlamaCli);
        }

        s.HideProjectors = chkHideProjectors.Checked;

        // Compute
        s.Threads = (int)numThreads.Value;
        s.GpuLayers = (int)numGpuLayers.Value;
        if (cmbContextSize.SelectedItem?.ToString() == "Custom...")
        {
            s.ContextSize = (int)numCustomContext.Value;
        }
        else if (int.TryParse(cmbContextSize.SelectedItem?.ToString(), out int ctx))
        {
            s.ContextSize = ctx;
        }
        else
        {
            s.ContextSize = 8192;
        }
        if (int.TryParse(cmbBatchSize.SelectedItem?.ToString(), out int bs)) s.BatchSize = bs;
        if (int.TryParse(cmbUBatchSize.SelectedItem?.ToString(), out int ubs)) s.UBatchSize = ubs;

        // Memory
        s.CacheTypeK = cmbCacheK.SelectedItem?.ToString() ?? "f16";
        s.CacheTypeV = cmbCacheV.SelectedItem?.ToString() ?? "f16";
        s.FlashAttention = cmbFlashAttn.SelectedItem?.ToString() ?? "auto";
        s.MLock = chkMlock.Checked;
        s.NoMMap = chkNoMMap.Checked;

        // Sampling
        s.Temperature = (double)numTemp.Value;
        s.TopP = (double)numTopP.Value;
        s.TopK = (int)numTopK.Value;
        s.MinP = (double)numMinP.Value;
        s.RepeatPenalty = (double)numRepeatPenalty.Value;
        s.RepeatLastN = (int)numRepeatLastN.Value;

        string? maxTokStr = cmbMaxTokens.SelectedItem?.ToString();
        if (maxTokStr != null && int.TryParse(maxTokStr, out int maxTok))
        {
            s.MaxTokens = maxTok;
        }
        else
        {
            s.MaxTokens = -1;
        }

        s.Save();
        onSettingsSaved?.Invoke();
        Close();
    }

    private async void DownloadLlamaCppAsync()
    {
        btnDownloadLlama.Enabled = false;
        string originalText = btnDownloadLlama.Text;
        btnDownloadLlama.Text = "Checking releases...";

        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("eLlama-Updater");

            // 1. Query GitHub releases
            string apiUrl = "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=5";
            string json = await http.GetStringAsync(apiUrl);

            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0)
            {
                throw new Exception("No releases found on ggml-org/llama.cpp.");
            }

            var latestRelease = doc.RootElement[0];
            string tagName = latestRelease.GetProperty("tag_name").GetString() ?? "latest";

            // 2. Find Vulkan asset (fallback CPU)
            string? downloadUrl = null;
            string? assetName = null;

            if (latestRelease.TryGetProperty("assets", out var assets) && assets.ValueKind == JsonValueKind.Array)
            {
                foreach (var asset in assets.EnumerateArray())
                {
                    string name = asset.GetProperty("name").GetString() ?? "";
                    if (name.Contains("win", StringComparison.OrdinalIgnoreCase) &&
                        name.Contains("vulkan", StringComparison.OrdinalIgnoreCase) &&
                        name.Contains("x64", StringComparison.OrdinalIgnoreCase) &&
                        name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                    {
                        downloadUrl = asset.GetProperty("browser_download_url").GetString();
                        assetName = name;
                        break;
                    }
                }

                // Fallback to CPU if Vulkan not found
                if (downloadUrl == null)
                {
                    foreach (var asset in assets.EnumerateArray())
                    {
                        string name = asset.GetProperty("name").GetString() ?? "";
                        if (name.Contains("win", StringComparison.OrdinalIgnoreCase) &&
                            name.Contains("cpu", StringComparison.OrdinalIgnoreCase) &&
                            name.Contains("x64", StringComparison.OrdinalIgnoreCase) &&
                            name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                        {
                            downloadUrl = asset.GetProperty("browser_download_url").GetString();
                            assetName = name;
                            break;
                        }
                    }
                }
            }

            if (string.IsNullOrEmpty(downloadUrl))
            {
                throw new Exception($"Could not find a Windows x64 release asset in llama.cpp {tagName}.");
            }

            var confirm = MessageBox.Show(
                $"Found latest release: {tagName}\nAsset: {assetName}\n\nWould you like to download and install this into '.\\llama.cpp\\'?",
                "Download llama.cpp",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question
            );

            if (confirm != DialogResult.Yes)
            {
                btnDownloadLlama.Text = originalText;
                btnDownloadLlama.Enabled = true;
                return;
            }

            // 3. Download
            btnDownloadLlama.Text = "Downloading...";
            string tempZip = Path.Combine(Path.GetTempPath(), $"llama_{Guid.NewGuid():N}.zip");

            using (var response = await http.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead))
            {
                response.EnsureSuccessStatusCode();
                long? totalBytes = response.Content.Headers.ContentLength;

                using var stream = await response.Content.ReadAsStreamAsync();
                using var fileStream = new FileStream(tempZip, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true);

                var buffer = new byte[81920];
                long totalRead = 0;
                int read;
                DateTime lastUpdate = DateTime.Now;

                while ((read = await stream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    await fileStream.WriteAsync(buffer, 0, read);
                    totalRead += read;

                    if ((DateTime.Now - lastUpdate).TotalMilliseconds > 250)
                    {
                        lastUpdate = DateTime.Now;
                        if (totalBytes.HasValue && totalBytes.Value > 0)
                        {
                            int pct = (int)((totalRead * 100) / totalBytes.Value);
                            btnDownloadLlama.Text = $"Downloading {pct}%...";
                        }
                        else
                        {
                            btnDownloadLlama.Text = $"Downloading ({totalRead / (1024 * 1024)} MB)...";
                        }
                    }
                }
            }

            // 4. Extract
            btnDownloadLlama.Text = "Extracting...";
            string targetDir = Path.Combine(AppSettings.AppDir, "llama.cpp");
            Directory.CreateDirectory(targetDir);

            ZipFile.ExtractToDirectory(tempZip, targetDir, overwriteFiles: true);

            try { File.Delete(tempZip); } catch { }

            // 5. Update Path
            string relativeCli = Path.Combine("llama.cpp", "llama-cli.exe");
            txtLlamaCli.Text = relativeCli;
            AppSettings.Instance.LlamaCliPath = relativeCli;
            AppSettings.Instance.Save();

            MessageBox.Show(
                $"Successfully updated llama.cpp to {tagName} (Vulkan)!\n\nTarget directory:\n{targetDir}\n\nExecutable path configured to:\n{relativeCli}",
                "llama.cpp Update Complete",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Failed to download llama.cpp:\n{ex.Message}",
                "Download Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
        finally
        {
            btnDownloadLlama.Text = originalText;
            btnDownloadLlama.Enabled = true;
        }
    }

    private void ExportModels()
    {
        var models = GetModelsForExport();
        if (models.Count == 0)
        {
            MessageBox.Show(
                "No models found to export.\n\nPlease ensure your models directory is set correctly and contains .gguf files.",
                "Export Models",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );
            return;
        }

        int formatIndex = cmbExportFormat.SelectedIndex;
        if (formatIndex < 0) formatIndex = 0;

        using var sfd = new SaveFileDialog
        {
            Title = "Export Model List",
            Filter = "CSV Document (*.csv)|*.csv|JSON Document (*.json)|*.json|Markdown Document (*.md)|*.md|Text Document (*.txt)|*.txt",
            FilterIndex = formatIndex + 1,
            FileName = $"eLlama_models_{DateTime.Now:yyyyMMdd_HHmmss}"
        };

        if (sfd.ShowDialog(this) != DialogResult.OK) return;

        string ext = Path.GetExtension(sfd.FileName).ToLowerInvariant();
        int effectiveFormat = ext switch
        {
            ".csv" => 0,
            ".json" => 1,
            ".md" => 2,
            ".txt" => 3,
            _ => sfd.FilterIndex - 1
        };

        try
        {
            string content = effectiveFormat switch
            {
                0 => GenerateCsv(models),
                1 => GenerateJson(models),
                2 => GenerateMarkdown(models),
                _ => GeneratePlainText(models)
            };

            File.WriteAllText(sfd.FileName, content, Encoding.UTF8);

            var res = MessageBox.Show(
                $"Successfully exported {models.Count} models to:\n{sfd.FileName}\n\nWould you like to open the export file?",
                "Export Complete",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information
            );
            if (res == DialogResult.Yes)
            {
                Process.Start("explorer.exe", $"/select,\"{sfd.FileName}\"");
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Failed to export model list:\n{ex.Message}",
                "Export Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
    }

    private List<ModelInfo> GetModelsForExport()
    {
        if (currentModels != null && currentModels.Count > 0)
            return currentModels;

        var list = new List<ModelInfo>();
        string dir = txtDirectory.Text.Trim();
        if (Directory.Exists(dir))
        {
            foreach (var file in Directory.GetFiles(dir, "*.gguf", SearchOption.AllDirectories))
            {
                var fi = new FileInfo(file);
                list.Add(new ModelInfo
                {
                    FilePath = fi.FullName,
                    FileName = fi.Name,
                    ModelName = Path.GetFileNameWithoutExtension(fi.Name),
                    Publisher = "Local",
                    Quant = "Unknown",
                    SizeBytes = fi.Length,
                    IsProjector = fi.Name.StartsWith("mmproj", StringComparison.OrdinalIgnoreCase)
                });
            }
        }
        return list;
    }

    private static string GenerateCsv(List<ModelInfo> models)
    {
        var sb = new StringBuilder();
        sb.AppendLine("Model Name,Quantization,Size,Bytes,Publisher,Filename,File Path,Is Projector");

        foreach (var m in models)
        {
            sb.AppendLine($"\"{EscapeCsv(m.ModelName)}\",\"{EscapeCsv(m.Quant)}\",\"{FormatBytes(m.SizeBytes)}\",{m.SizeBytes},\"{EscapeCsv(m.Publisher)}\",\"{EscapeCsv(m.FileName)}\",\"{EscapeCsv(m.FilePath)}\",{(m.IsProjector ? "Yes" : "No")}");
        }

        return sb.ToString();
    }

    private static string GenerateJson(List<ModelInfo> models)
    {
        var list = models.Select(m => new
        {
            model_name = m.ModelName,
            quantization = m.Quant,
            size_formatted = FormatBytes(m.SizeBytes),
            size_bytes = m.SizeBytes,
            publisher = m.Publisher,
            filename = m.FileName,
            file_path = m.FilePath,
            is_projector = m.IsProjector
        });

        return JsonSerializer.Serialize(list, new JsonSerializerOptions { WriteIndented = true });
    }

    private static string GenerateMarkdown(List<ModelInfo> models)
    {
        var sb = new StringBuilder();
        long totalBytes = models.Sum(m => m.SizeBytes);

        sb.AppendLine("# eLlama Model Library Export");
        sb.AppendLine();
        sb.AppendLine($"- **Export Date**: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        sb.AppendLine($"- **Total Models**: {models.Count}");
        sb.AppendLine($"- **Total Storage**: {FormatBytes(totalBytes)}");
        sb.AppendLine();
        sb.AppendLine("## Models Overview");
        sb.AppendLine();
        sb.AppendLine("| Model Name | Quant | Size | Publisher | Filename |");
        sb.AppendLine("| :--- | :--- | :---: | :--- | :--- |");

        foreach (var m in models)
        {
            string name = m.ModelName.Replace("|", "\\|");
            string quant = m.Quant.Replace("|", "\\|");
            string size = FormatBytes(m.SizeBytes);
            string pub = m.Publisher.Replace("|", "\\|");
            string file = m.FileName.Replace("|", "\\|");
            sb.AppendLine($"| {name} | {quant} | {size} | {pub} | `{file}` |");
        }

        sb.AppendLine();
        sb.AppendLine("## File Paths");
        sb.AppendLine();
        for (int i = 0; i < models.Count; i++)
        {
            sb.AppendLine($"{i + 1}. `{models[i].FilePath}`");
        }

        return sb.ToString();
    }

    private static string GeneratePlainText(List<ModelInfo> models)
    {
        var sb = new StringBuilder();
        long totalBytes = models.Sum(m => m.SizeBytes);

        sb.AppendLine("================================================================================");
        sb.AppendLine("eLlama Model Library Export");
        sb.AppendLine($"Date:         {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        sb.AppendLine($"Total Models: {models.Count}");
        sb.AppendLine($"Total Size:   {FormatBytes(totalBytes)}");
        sb.AppendLine("================================================================================");
        sb.AppendLine();

        for (int i = 0; i < models.Count; i++)
        {
            var m = models[i];
            sb.AppendLine($"[{i + 1}] {m.ModelName}");
            sb.AppendLine($"    Quantization: {m.Quant}");
            sb.AppendLine($"    Size:         {FormatBytes(m.SizeBytes)} ({m.SizeBytes:N0} bytes)");
            sb.AppendLine($"    Publisher:    {m.Publisher}");
            sb.AppendLine($"    Filename:     {m.FileName}");
            sb.AppendLine($"    Path:         {m.FilePath}");
            if (m.IsProjector)
            {
                sb.AppendLine("    Type:         Vision Projector");
            }
            sb.AppendLine(new string('-', 80));
        }

        return sb.ToString();
    }

    private static string EscapeCsv(string text)
    {
        return text?.Replace("\"", "\"\"") ?? "";
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes >= 1024L * 1024L * 1024L)
            return (bytes / (1024.0 * 1024.0 * 1024.0)).ToString("F2") + " GB";
        if (bytes >= 1024L * 1024L)
            return (bytes / (1024.0 * 1024.0)).ToString("F2") + " MB";
        return (bytes / 1024.0).ToString("F2") + " KB";
    }

    private void BuildAboutTab(TabPage tab)
    {
        var lblTitle = new Label
        {
            Text = "eLlama v1.1.1",
            Font = new Font(Font.FontFamily, 14, FontStyle.Bold),
            Location = new Point(14, 14),
            AutoSize = true
        };

        var lblSubtitle = new Label
        {
            Text = "Native Windows Desktop Manager & Runner for Local GGUF LLMs\nCopyright © 2026 Raudel. Licensed under the MIT License.",
            Location = new Point(16, 44),
            AutoSize = true,
            ForeColor = SystemColors.GrayText
        };

        var grpCredits = new GroupBox
        {
            Text = "Core Technologies & Acknowledgements",
            Location = new Point(12, 85),
            Size = new Size(590, 115)
        };

        var lblLlamaCred = new Label
        {
            Text = "• llama.cpp: Developed by Georgi Gerganov & the llama.cpp community (MIT License)\n  High-performance C++ LLM inference engine powering local models.",
            Location = new Point(14, 22),
            Size = new Size(470, 32)
        };

        var btnLlamaLink = new Button
        {
            Text = "GitHub",
            Location = new Point(495, 20),
            Size = new Size(80, 25)
        };
        btnLlamaLink.Click += (s, e) =>
        {
            try { Process.Start(new ProcessStartInfo("https://github.com/ggml-org/llama.cpp") { UseShellExecute = true }); } catch { }
        };

        var lblOtherCreds = new Label
        {
            Text = "• Vulkan: Cross-vendor GPU compute & acceleration by The Khronos Group Inc.\n• LLVM OpenMP: High-performance parallel multi-threading runtime (Apache 2.0 / LLVM)\n• Microsoft .NET 10: Desktop runtime and Windows Forms application platform (MIT License)",
            Location = new Point(14, 58),
            Size = new Size(560, 48)
        };

        grpCredits.Controls.AddRange(new Control[] { lblLlamaCred, btnLlamaLink, lblOtherCreds });

        var grpLicenses = new GroupBox
        {
            Text = "Third-Party Legal Notices & Licenses",
            Location = new Point(12, 210),
            Size = new Size(590, 255)
        };

        var txtLicenses = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            Location = new Point(14, 22),
            Size = new Size(560, 190),
            Font = new Font("Consolas", 8.25f),
            BackColor = Color.FromArgb(250, 250, 250),
            Text = GetThirdPartyNoticesText()
        };

        var btnOpenNoticeFile = new Button
        {
            Text = "Open License File",
            Location = new Point(14, 220),
            Size = new Size(130, 26)
        };
        btnOpenNoticeFile.Click += (s, e) =>
        {
            string noticeFile = Path.Combine(AppSettings.AppDir, "THIRD-PARTY-NOTICES.md");
            if (!File.Exists(noticeFile))
            {
                noticeFile = Path.Combine(AppSettings.AppDir, "LICENSE");
            }
            if (File.Exists(noticeFile))
            {
                try { Process.Start(new ProcessStartInfo(noticeFile) { UseShellExecute = true }); } catch { }
            }
            else
            {
                MessageBox.Show("License file not found on disk.", "License Notice", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        };

        var btnViewRepo = new Button
        {
            Text = "eLlama GitHub Repository",
            Location = new Point(152, 220),
            Size = new Size(170, 26)
        };
        btnViewRepo.Click += (s, e) =>
        {
            try { Process.Start(new ProcessStartInfo("https://github.com/r0bledas/eLlama") { UseShellExecute = true }); } catch { }
        };

        grpLicenses.Controls.AddRange(new Control[] { txtLicenses, btnOpenNoticeFile, btnViewRepo });

        tab.Controls.AddRange(new Control[] { lblTitle, lblSubtitle, grpCredits, grpLicenses });
    }

    private static string GetThirdPartyNoticesText()
    {
        return @"eLlama Third-Party Notices and Open-Source Licenses:

================================================================================
1. llama.cpp
Copyright (c) 2023-2025 Georgi Gerganov and llama.cpp contributors
License: MIT License
URL: https://github.com/ggml-org/llama.cpp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the ""Software""), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND.

================================================================================
2. ggml
Copyright (c) 2022-2025 Georgi Gerganov and ggml contributors
License: MIT License
URL: https://github.com/ggml-org/ggml

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the ""Software""), to deal
in the Software without restriction.

================================================================================
3. LLVM OpenMP (libomp.dll)
Copyright (c) 1997-2025 LLVM Release Engineering
License: Apache License v2.0 with LLVM Exceptions
URL: https://openmp.llvm.org/

Licensed under the Apache License, Version 2.0.

================================================================================
4. Vulkan (ggml-vulkan.dll)
Copyright (c) 2015-2025 The Khronos Group Inc.
License: Apache License v2.0 / MIT
URL: https://www.vulkan.org/

================================================================================
5. Microsoft .NET 10 Runtime & Windows Forms
Copyright (c) .NET Foundation and Contributors
License: MIT License
URL: https://github.com/dotnet/runtime";
    }
}

