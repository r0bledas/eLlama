namespace eLlama;

public class SettingsForm : Form
{
    // General Tab
    private TextBox txtDirectory = null!;
    private TextBox txtLlamaCli = null!;
    private CheckBox chkHideProjectors = null!;

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

    private readonly Action onSettingsSaved;

    public SettingsForm(Action onSaved)
    {
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

        BuildGeneralTab(tabGeneral);
        BuildAdvancedTab(tabAdvanced);

        tabControl.TabPages.Add(tabGeneral);
        tabControl.TabPages.Add(tabAdvanced);

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
            using var fbd = new FolderBrowserDialog
            {
                SelectedPath = Directory.Exists(txtDirectory.Text) ? txtDirectory.Text : @"C:\"
            };
            if (fbd.ShowDialog(this) == DialogResult.OK)
            {
                txtDirectory.Text = fbd.SelectedPath;
            }
        };

        grpDirectory.Controls.AddRange(new Control[] { lblDir, txtDirectory, btnBrowse });

        // Backend
        var grpBackend = new GroupBox
        {
            Text = "llama.cpp Backend",
            Location = new Point(12, 102),
            Size = new Size(590, 80)
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
            using var ofd = new OpenFileDialog
            {
                Title = "Select llama-cli.exe",
                Filter = "llama-cli.exe|llama-cli*.exe|All Executables (*.exe)|*.exe",
                InitialDirectory = Directory.Exists(@"C:\Users\T450\Utilities\llama.cpp")
                    ? @"C:\Users\T450\Utilities\llama.cpp"
                    : @"C:\"
            };
            if (ofd.ShowDialog(this) == DialogResult.OK)
            {
                txtLlamaCli.Text = ofd.FileName;
            }
        };

        grpBackend.Controls.AddRange(new Control[] { lblLlama, txtLlamaCli, btnBrowseLlama });

        // Display Preferences
        var grpFilter = new GroupBox
        {
            Text = "Display & Filtering",
            Location = new Point(12, 192),
            Size = new Size(590, 70)
        };

        chkHideProjectors = new CheckBox
        {
            Text = "Hide Vision Projectors (mmproj files) by default",
            Location = new Point(14, 28),
            AutoSize = true
        };

        grpFilter.Controls.Add(chkHideProjectors);

        tab.Controls.AddRange(new Control[] { grpDirectory, grpBackend, grpFilter });
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
        if (!string.IsNullOrEmpty(newDir) && Directory.Exists(newDir))
        {
            s.ModelsDirectory = newDir;
        }

        string newLlamaCli = txtLlamaCli.Text.Trim();
        if (!string.IsNullOrEmpty(newLlamaCli))
        {
            s.LlamaCliPath = newLlamaCli;
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
}
