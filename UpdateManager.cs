using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace eLlama;

public record UpdateResult(bool HasUpdate, string CurrentVersion, string LatestVersion, string ReleaseUrl, string? AssetDownloadUrl);

public static class UpdateManager
{
    public const string CurrentELlamaVersion = "1.1.2";

    public static async Task<UpdateResult> CheckELlamaAsync()
    {
        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("eLlama-Updater");

            string json = await http.GetStringAsync("https://api.github.com/repos/r0bledas/eLlama/releases?per_page=5");
            using var doc = JsonDocument.Parse(json);

            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0)
            {
                return new UpdateResult(false, CurrentELlamaVersion, CurrentELlamaVersion, "https://github.com/r0bledas/eLlama/releases", null);
            }

            var latest = doc.RootElement[0];
            string tagName = latest.GetProperty("tag_name").GetString() ?? "";
            string htmlUrl = latest.GetProperty("html_url").GetString() ?? "https://github.com/r0bledas/eLlama/releases";

            string cleanLatest = tagName.TrimStart('v', 'V');
            string cleanCurrent = CurrentELlamaVersion.TrimStart('v', 'V');

            if (Version.TryParse(cleanLatest, out var vLatest) && Version.TryParse(cleanCurrent, out var vCurrent))
            {
                if (vLatest > vCurrent)
                {
                    return new UpdateResult(true, CurrentELlamaVersion, tagName, htmlUrl, null);
                }
            }
            else if (!string.Equals(cleanLatest, cleanCurrent, StringComparison.OrdinalIgnoreCase))
            {
                return new UpdateResult(true, CurrentELlamaVersion, tagName, htmlUrl, null);
            }

            return new UpdateResult(false, CurrentELlamaVersion, tagName, htmlUrl, null);
        }
        catch
        {
            return new UpdateResult(false, CurrentELlamaVersion, CurrentELlamaVersion, "https://github.com/r0bledas/eLlama/releases", null);
        }
    }

    public static async Task<UpdateResult> CheckLlamaCppAsync()
    {
        string currentBuild = DetectInstalledLlamaCppBuild();
        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("eLlama-Updater");

            string json = await http.GetStringAsync("https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=5");
            using var doc = JsonDocument.Parse(json);

            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0)
            {
                return new UpdateResult(false, currentBuild, currentBuild, "https://github.com/ggml-org/llama.cpp/releases", null);
            }

            var latest = doc.RootElement[0];
            string tagName = latest.GetProperty("tag_name").GetString() ?? "";
            string htmlUrl = latest.GetProperty("html_url").GetString() ?? "https://github.com/ggml-org/llama.cpp/releases";

            string? vulkanUrl = null;
            if (latest.TryGetProperty("assets", out var assets) && assets.ValueKind == JsonValueKind.Array)
            {
                foreach (var asset in assets.EnumerateArray())
                {
                    string name = asset.GetProperty("name").GetString() ?? "";
                    if (name.Contains("win", StringComparison.OrdinalIgnoreCase) &&
                        name.Contains("vulkan", StringComparison.OrdinalIgnoreCase) &&
                        name.Contains("x64", StringComparison.OrdinalIgnoreCase) &&
                        name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                    {
                        vulkanUrl = asset.GetProperty("browser_download_url").GetString();
                        break;
                    }
                }
            }

            int latestNum = ParseBuildNumber(tagName);
            int currentNum = ParseBuildNumber(currentBuild);

            if (latestNum > 0 && currentNum > 0)
            {
                if (latestNum > currentNum)
                {
                    return new UpdateResult(true, currentBuild, tagName, htmlUrl, vulkanUrl);
                }
            }
            else if (!string.IsNullOrEmpty(tagName) && !string.Equals(tagName, currentBuild, StringComparison.OrdinalIgnoreCase))
            {
                return new UpdateResult(true, currentBuild, tagName, htmlUrl, vulkanUrl);
            }

            return new UpdateResult(false, currentBuild, tagName, htmlUrl, vulkanUrl);
        }
        catch
        {
            return new UpdateResult(false, currentBuild, currentBuild, "https://github.com/ggml-org/llama.cpp/releases", null);
        }
    }

    public static string DetectInstalledLlamaCppBuild()
    {
        if (!string.IsNullOrWhiteSpace(AppSettings.Instance.InstalledLlamaCppVersion))
        {
            return AppSettings.Instance.InstalledLlamaCppVersion;
        }

        string cliPath = AppSettings.Instance.ResolvedLlamaCliPath;
        if (File.Exists(cliPath))
        {
            try
            {
                using var p = new Process();
                p.StartInfo = new ProcessStartInfo
                {
                    FileName = cliPath,
                    Arguments = "--version",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                p.Start();
                string output = p.StandardOutput.ReadToEnd();
                p.WaitForExit(3000);

                var match = Regex.Match(output, @"build\s+(\d+)", RegexOptions.IgnoreCase);
                if (match.Success)
                {
                    string build = "b" + match.Groups[1].Value;
                    AppSettings.Instance.InstalledLlamaCppVersion = build;
                    AppSettings.Instance.Save();
                    return build;
                }
            }
            catch { }
        }

        return "Unknown";
    }

    private static int ParseBuildNumber(string tag)
    {
        var match = Regex.Match(tag, @"\d+");
        if (match.Success && int.TryParse(match.Value, out int n))
        {
            return n;
        }
        return -1;
    }

    public static async Task CheckStartupUpdatesAsync(Form parent)
    {
        await Task.Delay(2000);

        if (AppSettings.Instance.CheckForELlamaUpdates)
        {
            var eLlamaRes = await CheckELlamaAsync();
            if (eLlamaRes.HasUpdate && parent.IsHandleCreated)
            {
                parent.BeginInvoke(() =>
                {
                    var prompt = MessageBox.Show(
                        parent,
                        $"A new version of eLlama is available!\n\nCurrent version: {eLlamaRes.CurrentVersion}\nLatest release: {eLlamaRes.LatestVersion}\n\nWould you like to open the GitHub releases page to download the update?",
                        "eLlama Update Available",
                        MessageBoxButtons.YesNo,
                        MessageBoxIcon.Information
                    );

                    if (prompt == DialogResult.Yes)
                    {
                        try { Process.Start(new ProcessStartInfo(eLlamaRes.ReleaseUrl) { UseShellExecute = true }); } catch { }
                    }
                });
            }
        }

        if (AppSettings.Instance.CheckForLlamaCppUpdates)
        {
            var llamaRes = await CheckLlamaCppAsync();
            if (llamaRes.HasUpdate && parent.IsHandleCreated)
            {
                parent.BeginInvoke(() =>
                {
                    var prompt = MessageBox.Show(
                        parent,
                        $"A new build of llama.cpp (Vulkan) is available!\n\nInstalled: {llamaRes.CurrentVersion}\nLatest: {llamaRes.LatestVersion}\n\nWould you like to open Settings to download and install the latest llama.cpp binaries?",
                        "llama.cpp Update Available",
                        MessageBoxButtons.YesNo,
                        MessageBoxIcon.Information
                    );

                    if (prompt == DialogResult.Yes)
                    {
                        // Open Settings dialog
                        if (parent is MainForm mf)
                        {
                            mf.OpenSettingsToUpdates();
                        }
                    }
                });
            }
        }
    }

    public static async Task CheckAllUpdatesInteractiveAsync(Form parent, Action? openSettingsAction = null)
    {
        var eLlamaTask = CheckELlamaAsync();
        var llamaTask = CheckLlamaCppAsync();

        await Task.WhenAll(eLlamaTask, llamaTask);

        var eRes = eLlamaTask.Result;
        var lRes = llamaTask.Result;

        if (eRes.HasUpdate && lRes.HasUpdate)
        {
            var msg = MessageBox.Show(
                parent,
                $"Updates are available for both eLlama and llama.cpp!\n\n• eLlama: {eRes.CurrentVersion} -> {eRes.LatestVersion}\n• llama.cpp: {lRes.CurrentVersion} -> {lRes.LatestVersion}\n\nWould you like to open the eLlama releases page?",
                "Updates Available",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information
            );
            if (msg == DialogResult.Yes)
            {
                try { Process.Start(new ProcessStartInfo(eRes.ReleaseUrl) { UseShellExecute = true }); } catch { }
            }
        }
        else if (eRes.HasUpdate)
        {
            var msg = MessageBox.Show(
                parent,
                $"A new version of eLlama is available!\n\nCurrent version: {eRes.CurrentVersion}\nLatest version:  {eRes.LatestVersion}\n\nWould you like to open the GitHub releases page to download it?",
                "eLlama Update Available",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information
            );
            if (msg == DialogResult.Yes)
            {
                try { Process.Start(new ProcessStartInfo(eRes.ReleaseUrl) { UseShellExecute = true }); } catch { }
            }
        }
        else if (lRes.HasUpdate)
        {
            var msg = MessageBox.Show(
                parent,
                $"A new build of llama.cpp (Vulkan) is available!\n\nInstalled: {lRes.CurrentVersion}\nLatest:    {lRes.LatestVersion}\n\nWould you like to open Settings to download and install this build now?",
                "llama.cpp Update Available",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information
            );
            if (msg == DialogResult.Yes)
            {
                openSettingsAction?.Invoke();
            }
        }
        else
        {
            MessageBox.Show(
                parent,
                $"Everything is up to date!\n\n• eLlama: v{CurrentELlamaVersion} (Latest)\n• llama.cpp: {lRes.CurrentVersion} (Latest)",
                "No Updates Available",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );
        }
    }
}
