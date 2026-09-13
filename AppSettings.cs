using System.Text.Json;

namespace eLlama;

public class AppSettings
{
    private static readonly string SettingsFolder = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "eLlama"
    );

    private static readonly string SettingsFile = Path.Combine(SettingsFolder, "settings.json");

    private static AppSettings? instance;
    public static AppSettings Instance => instance ??= Load();

    // General
    public string ModelsDirectory { get; set; } = @"C:\llms";
    public string LlamaCliPath { get; set; } = @"C:\Users\T450\Utilities\llama.cpp\llama-cli.exe";
    public bool HideProjectors { get; set; } = true;

    // Hardware & Compute
    public int Threads { get; set; } = 4;
    public int GpuLayers { get; set; } = 0;
    public int ContextSize { get; set; } = 8192;
    public int BatchSize { get; set; } = 512;
    public int UBatchSize { get; set; } = 512;

    // KV Cache & Memory
    public string CacheTypeK { get; set; } = "f16";
    public string CacheTypeV { get; set; } = "f16";
    public string FlashAttention { get; set; } = "auto";
    public bool MLock { get; set; } = false;
    public bool NoMMap { get; set; } = false;

    // Sampling & Generation
    public double Temperature { get; set; } = 0.80;
    public double TopP { get; set; } = 0.95;
    public int TopK { get; set; } = 40;
    public double MinP { get; set; } = 0.05;
    public double RepeatPenalty { get; set; } = 1.10;
    public int RepeatLastN { get; set; } = 64;
    public int MaxTokens { get; set; } = -1;

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(SettingsFile))
            {
                string json = File.ReadAllText(SettingsFile);
                var settings = JsonSerializer.Deserialize<AppSettings>(json);
                if (settings != null)
                {
                    if (string.IsNullOrWhiteSpace(settings.LlamaCliPath))
                    {
                        settings.LlamaCliPath = @"C:\Users\T450\Utilities\llama.cpp\llama-cli.exe";
                    }
                    return settings;
                }
            }
        }
        catch { }

        return new AppSettings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(SettingsFolder);
            string json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsFile, json);
        }
        catch { }
    }
}
