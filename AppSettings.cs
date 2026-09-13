using System.Text.Json;
using System.Text.Json.Serialization;

namespace eLlama;

public class AppSettings
{
    public static string AppDir => AppContext.BaseDirectory;

    private static AppSettings? instance;
    public static AppSettings Instance => instance ??= Load();

    // General
    public string ModelsDirectory { get; set; } = GetDefaultModelsDirectory();
    public string LlamaCliPath { get; set; } = GetDefaultLlamaCliPath();
    public bool HideProjectors { get; set; } = true;

    [JsonIgnore]
    public string ResolvedModelsDirectory => ResolvePath(ModelsDirectory);

    [JsonIgnore]
    public string ResolvedLlamaCliPath => ResolvePath(LlamaCliPath);

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

    public static string GetDefaultModelsDirectory()
    {
        string localModels = Path.Combine(AppDir, "models");
        if (Directory.Exists(localModels)) return "models";
        if (Directory.Exists(@"C:\llms")) return @"C:\llms";
        return "models";
    }

    public static string GetDefaultLlamaCliPath()
    {
        string inSubdir = Path.Combine(AppDir, "llama.cpp", "llama-cli.exe");
        if (File.Exists(inSubdir)) return Path.Combine("llama.cpp", "llama-cli.exe");

        string nextToExe = Path.Combine(AppDir, "llama-cli.exe");
        if (File.Exists(nextToExe)) return "llama-cli.exe";

        string utilPath = @"C:\Users\T450\Utilities\llama.cpp\llama-cli.exe";
        if (File.Exists(utilPath)) return utilPath;

        return Path.Combine("llama.cpp", "llama-cli.exe");
    }

    public static string GetSettingsFilePath()
    {
        string localSettings = Path.Combine(AppDir, "settings.json");
        if (File.Exists(localSettings))
            return localSettings;

        try
        {
            string testFile = Path.Combine(AppDir, ".write_test_" + Guid.NewGuid().ToString("N"));
            File.WriteAllText(testFile, "");
            File.Delete(testFile);
            return localSettings;
        }
        catch
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "eLlama",
                "settings.json"
            );
        }
    }

    public static string ResolvePath(string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return "";
        if (Path.IsPathRooted(path)) return path;
        return Path.GetFullPath(Path.Combine(AppDir, path));
    }

    public static string ToRelativePath(string? fullPath)
    {
        if (string.IsNullOrWhiteSpace(fullPath)) return "";
        try
        {
            string baseDir = AppDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
            if (fullPath.StartsWith(baseDir, StringComparison.OrdinalIgnoreCase))
            {
                return Path.GetRelativePath(baseDir, fullPath);
            }
        }
        catch { }
        return fullPath;
    }

    public static AppSettings Load()
    {
        string settingsFile = GetSettingsFilePath();
        try
        {
            if (File.Exists(settingsFile))
            {
                string json = File.ReadAllText(settingsFile);
                var settings = JsonSerializer.Deserialize<AppSettings>(json);
                if (settings != null)
                {
                    if (string.IsNullOrWhiteSpace(settings.ModelsDirectory))
                    {
                        settings.ModelsDirectory = GetDefaultModelsDirectory();
                    }
                    if (string.IsNullOrWhiteSpace(settings.LlamaCliPath))
                    {
                        settings.LlamaCliPath = GetDefaultLlamaCliPath();
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
            string settingsFile = GetSettingsFilePath();
            string? dir = Path.GetDirectoryName(settingsFile);
            if (!string.IsNullOrEmpty(dir))
            {
                Directory.CreateDirectory(dir);
            }

            string json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(settingsFile, json);
        }
        catch { }
    }
}
