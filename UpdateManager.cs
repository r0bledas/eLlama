using System.Diagnostics;
using System.IO.Compression;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace eLlama;

public record UpdateResult(bool HasUpdate, string CurrentVersion, string LatestVersion, string ReleaseUrl, string? AssetDownloadUrl);

public static class UpdateManager
{
    public const string CurrentELlamaVersion = "1.1.4";

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

            string? setupUrl = null;
            if (latest.TryGetProperty("assets", out var assets) && assets.ValueKind == JsonValueKind.Array)
            {
                foreach (var asset in assets.EnumerateArray())
                {
                    string name = asset.GetProperty("name").GetString() ?? "";
                    if (name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) &&
                        (name.Contains("Setup", StringComparison.OrdinalIgnoreCase) || name.Contains("installer", StringComparison.OrdinalIgnoreCase)))
                    {
                        setupUrl = asset.GetProperty("browser_download_url").GetString();
                        break;
                    }
                }
            }

            string cleanLatest = tagName.TrimStart('v', 'V');
            string cleanCurrent = CurrentELlamaVersion.TrimStart('v', 'V');

            if (Version.TryParse(cleanLatest, out var vLatest) && Version.TryParse(cleanCurrent, out var vCurrent))
            {
                if (vLatest > vCurrent)
                {
                    return new UpdateResult(true, CurrentELlamaVersion, tagName, htmlUrl, setupUrl);
                }
            }
            else if (!string.Equals(cleanLatest, cleanCurrent, StringComparison.OrdinalIgnoreCase))
            {
                return new UpdateResult(true, CurrentELlamaVersion, tagName, htmlUrl, setupUrl);
            }

            return new UpdateResult(false, CurrentELlamaVersion, tagName, htmlUrl, setupUrl);
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
                        $"A new build of llama.cpp (Vulkan) is available!\n\nInstalled: {llamaRes.CurrentVersion}\nLatest: {llamaRes.LatestVersion}\n\nWould you like to update llama.cpp now?",
                        "llama.cpp Update Available",
                        MessageBoxButtons.YesNo,
                        MessageBoxIcon.Information
                    );

                    if (prompt == DialogResult.Yes)
                    {
                        if (parent is MainForm mf)
                        {
                            _ = mf.PerformLlamaUpdateAsync(llamaRes.AssetDownloadUrl, llamaRes.LatestVersion);
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
                $"A new build of llama.cpp (Vulkan) is available!\n\nInstalled: {lRes.CurrentVersion}\nLatest:    {lRes.LatestVersion}\n\nWould you like to download and install this build now?",
                "llama.cpp Update Available",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information
            );
            if (msg == DialogResult.Yes)
            {
                if (openSettingsAction != null)
                {
                    openSettingsAction.Invoke();
                }
                else if (parent is MainForm mf)
                {
                    _ = mf.PerformLlamaUpdateAsync(lRes.AssetDownloadUrl, lRes.LatestVersion);
                }
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

    public static async Task<bool> DownloadAndInstallLlamaCppAsync(
        Action<string>? statusCallback = null,
        string? specificDownloadUrl = null,
        string? specificTagName = null)
    {
        using var http = new HttpClient();
        http.DefaultRequestHeaders.UserAgent.ParseAdd("eLlama-Updater");

        string? downloadUrl = specificDownloadUrl;
        string? tagName = specificTagName;

        if (string.IsNullOrEmpty(downloadUrl))
        {
            statusCallback?.Invoke("Checking releases...");
            string apiUrl = "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=5";
            string json = await http.GetStringAsync(apiUrl);
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0)
            {
                throw new Exception("No releases found on ggml-org/llama.cpp.");
            }
            var latestRelease = doc.RootElement[0];
            tagName = latestRelease.GetProperty("tag_name").GetString() ?? "latest";

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
                        break;
                    }
                }

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
                            break;
                        }
                    }
                }
            }
        }

        if (string.IsNullOrEmpty(downloadUrl))
        {
            throw new Exception("Could not find a compatible Windows x64 release asset for llama.cpp.");
        }

        statusCallback?.Invoke("Updating llama.cpp: 0%");
        string tempZip = Path.Combine(Path.GetTempPath(), $"llama_{Guid.NewGuid():N}.zip");

        try
        {
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

                    if ((DateTime.Now - lastUpdate).TotalMilliseconds > 200)
                    {
                        lastUpdate = DateTime.Now;
                        if (totalBytes.HasValue && totalBytes.Value > 0)
                        {
                            int pct = (int)((totalRead * 100) / totalBytes.Value);
                            statusCallback?.Invoke($"Updating llama.cpp: {pct}%");
                        }
                        else
                        {
                            statusCallback?.Invoke($"Updating llama.cpp: {totalRead / (1024 * 1024)} MB");
                        }
                    }
                }
            }

            // Extracting
            statusCallback?.Invoke("Installing...");
            string targetDir = Path.Combine(AppSettings.AppDir, "llama.cpp");
            Directory.CreateDirectory(targetDir);

            ZipFile.ExtractToDirectory(tempZip, targetDir, overwriteFiles: true);

            // Update AppSettings
            string relativeCli = Path.Combine("llama.cpp", "llama-cli.exe");
            AppSettings.Instance.LlamaCliPath = relativeCli;
            if (!string.IsNullOrEmpty(tagName))
            {
                AppSettings.Instance.InstalledLlamaCppVersion = tagName;
            }
            AppSettings.Instance.Save();

            statusCallback?.Invoke("Done");
            return true;
        }
        finally
        {
            try { if (File.Exists(tempZip)) File.Delete(tempZip); } catch { }
        }
    }

    public static async Task DownloadAndRunELlamaInstallerAsync(
        Form parent,
        string downloadUrl,
        string targetVersion,
        Action<string>? statusCallback = null)
    {
        string tempInstaller = Path.Combine(Path.GetTempPath(), $"eLlama-Setup-{targetVersion}_{Guid.NewGuid():N}.exe");

        try
        {
            statusCallback?.Invoke("Downloading 0%...");
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("eLlama-Updater");

            using (var response = await http.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead))
            {
                response.EnsureSuccessStatusCode();
                long? totalBytes = response.Content.Headers.ContentLength;

                using var stream = await response.Content.ReadAsStreamAsync();
                using var fileStream = new FileStream(tempInstaller, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true);

                var buffer = new byte[81920];
                long totalRead = 0;
                int read;
                DateTime lastUpdate = DateTime.Now;

                while ((read = await stream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    await fileStream.WriteAsync(buffer, 0, read);
                    totalRead += read;

                    if ((DateTime.Now - lastUpdate).TotalMilliseconds > 200)
                    {
                        lastUpdate = DateTime.Now;
                        if (totalBytes.HasValue && totalBytes.Value > 0)
                        {
                            int pct = (int)((totalRead * 100) / totalBytes.Value);
                            statusCallback?.Invoke($"Downloading {pct}%...");
                        }
                        else
                        {
                            statusCallback?.Invoke($"Downloading {totalRead / (1024 * 1024)} MB...");
                        }
                    }
                }
            }

            statusCallback?.Invoke("Ready to Install");

            var confirm = MessageBox.Show(
                parent,
                $"Download of eLlama {targetVersion} completed successfully!\n\nClick OK to close eLlama and run the installer. The installer file will be cleaned up automatically after installation.",
                "eLlama Update Ready",
                MessageBoxButtons.OKCancel,
                MessageBoxIcon.Information
            );

            if (confirm != DialogResult.OK)
            {
                try { File.Delete(tempInstaller); } catch { }
                return;
            }

            // Launch installer with self-cleaning command
            var psi = new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/c start /wait \"\" \"{tempInstaller}\" & del \"{tempInstaller}\"",
                UseShellExecute = false,
                CreateNoWindow = true
            };
            Process.Start(psi);

            Application.Exit();
            Environment.Exit(0);
        }
        catch (Exception ex)
        {
            try { if (File.Exists(tempInstaller)) File.Delete(tempInstaller); } catch { }
            MessageBox.Show(parent, $"Failed to download update:\n{ex.Message}", "Update Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
