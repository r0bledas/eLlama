namespace eLlama;

/// <summary>
/// Small confirmation dialog used by the pre-launch memory guardrail.
/// WinForms MessageBox cannot host a "Don't show again" checkbox, so we use a
/// minimal custom form instead.
/// </summary>
public sealed class MemoryWarningDialog : Form
{
    private readonly CheckBox chkSuppress = new();

    public bool Suppress => chkSuppress.Checked;

    public MemoryWarningDialog(string title, string message)
    {
        Text = title;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowInTaskbar = false;
        ClientSize = new Size(470, 210);

        var lblMessage = new Label
        {
            Text = message,
            Location = new Point(16, 16),
            Size = new Size(438, 148),
            AutoSize = false
        };

        chkSuppress.Text = "Don't show again";
        chkSuppress.Location = new Point(16, 172);
        chkSuppress.AutoSize = true;

        var btnProceed = new Button
        {
            Text = "Proceed",
            DialogResult = DialogResult.OK,
            Location = new Point(286, 168),
            Size = new Size(80, 26)
        };

        var btnCancel = new Button
        {
            Text = "Cancel",
            DialogResult = DialogResult.Cancel,
            Location = new Point(374, 168),
            Size = new Size(80, 26)
        };

        Controls.AddRange(new Control[] { lblMessage, chkSuppress, btnProceed, btnCancel });

        AcceptButton = btnProceed;
        CancelButton = btnCancel;
    }
}
