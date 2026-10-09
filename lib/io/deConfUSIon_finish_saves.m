function deConfUSIon_finish_saves()
% Finish/retry retained results without running PCA or registration again.
% Works with an already-open Studio, including an older assembled runtime.
fig=getappdata(0,'deConfUSIonMainFigure');
if ~isempty(fig) && isgraphics(fig)
    if isequal(getappdata(fig,'StudioActionBusy'),true)
        error('deConfUSIon:SaveBusy','Wait until the current analysis finishes, then run deConfUSIon_finish_saves again.');
    end
end
DataIO('retry');
DataIO('wait');
DataIO('recover',tempdir);
if ~isempty(fig) && isgraphics(fig)
    studio=guidata(fig);
    if isstruct(studio) && isfield(studio,'exportPath') && ~isempty(studio.exportPath)
        root=studio.exportPath;
        DataIO('recover',{fullfile(root,'Preprocessing'),fullfile(root,'P'), ...
            fullfile(root,'PSC'),fullfile(root,'PSC','P')});
    end
    DataIO('flushstudio',studio);
end
DataIO('wait');
fprintf('[Save] All retained results saved and verified. No analysis was rerun.\n');
end
