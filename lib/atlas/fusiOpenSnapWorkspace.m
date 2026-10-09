function process=fusiOpenSnapWorkspace(executable,workspace)
% Start the requested viewer with its own Qt environment and verify a window.
if isempty(executable)||~isfile(executable),error('deConfUSIon:SnapMissing','ITK-SNAP executable was not found.');end
if ~isfile(workspace),error('deConfUSIon:SnapWorkspace','The ITK-SNAP workspace is missing: %s',workspace);end
if ispc
    NET.addAssembly('System');
    info=System.Diagnostics.ProcessStartInfo();info.FileName=executable;
    info.Arguments=['-w "' char(workspace) '"'];info.UseShellExecute=false;
    info.WorkingDirectory=fileparts(executable);info.CreateNoWindow=true;
    info.RedirectStandardOutput=true;info.RedirectStandardError=true;
    % MATLAB injects its Qt plugin paths. They are incompatible with SNAP's
    % Qt build and can terminate it before a visible window is created.
    iterator=info.EnvironmentVariables.Keys.GetEnumerator();keys={};
    while iterator.MoveNext(),keys{end+1}=char(iterator.Current);end %#ok<AGROW>
    for k=1:numel(keys)
        name=keys{k};
        if startsWith(upper(name),'QT_') || startsWith(upper(name),'QML'),info.EnvironmentVariables.Remove(name);end
    end
    paths=strsplit(getenv('PATH'),pathsep);
    paths=paths(~contains(lower(string(paths)),lower(string(matlabroot))));
    info.EnvironmentVariables.Remove('PATH');
    info.EnvironmentVariables.Add('PATH',strjoin([{fileparts(executable)} paths],pathsep));
    info.WindowStyle=System.Diagnostics.ProcessWindowStyle.Normal;
    process=System.Diagnostics.Process.Start(info);
    output=process.StandardOutput.ReadToEndAsync();errors=process.StandardError.ReadToEndAsync();
    started=tic;
    while toc(started)<15
        process.Refresh();
        if process.HasExited
            detail=[char(output.Result) char(errors.Result)];
            error('deConfUSIon:SnapLaunch','ITK-SNAP exited before opening a window (code %d). %s',process.ExitCode,strtrim(detail));
        end
        if process.MainWindowHandle.ToInt64()~=0
            try
                NET.addAssembly('Microsoft.VisualBasic');Microsoft.VisualBasic.Interaction.AppActivate(process.Id);
            catch
                % A visible verified window remains usable if Windows focus
                % rules prevent bringing it in front of another application.
            end
            return;
        end
        drawnow;pause(.15);
    end
    error('deConfUSIon:SnapLaunch','ITK-SNAP started (PID %d), but no visible window was detected within 15 seconds. Workspace: %s',process.Id,workspace);
else
    args=java.util.ArrayList();args.add(executable);args.add('-w');args.add(workspace);
    builder=java.lang.ProcessBuilder(args);process=builder.start();
end
end
