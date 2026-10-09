function root=deConfUSIon_setup()
% Add only active modules. Never genpath backups, validation or other tools.
root=deConfUSIon_root();persistent lastPath
current=path;if isequal(current,lastPath),return;end
parts=strsplit(current,pathsep);
for k=1:numel(parts)
 folder=parts{k};
 if startsWith(folder,[root filesep],'IgnoreCase',true)
  relative=folder(numel(root)+2:end);first=regexp(relative,'^[^\\/]+','match','once');
  if startsWith(first,'_backup','IgnoreCase',true) || startsWith(first,'_quarantine','IgnoreCase',true) || ...
    any(strcmpi(first,{'validation','backups','_legacy_unused','_legacy_HUMOR_helpers','_archive_review','_health_reports','_patch_backups'}))
   rmpath(folder);
  end
 end
end
directories={root,fullfile(root,'atlas_tools'),fullfile(root,'acquisition')};
modules={'atlas','volume','roi','connectivity','group','display','io','preprocessing','metadata'};
for k=1:numel(modules),directories{end+1}=fullfile(root,'lib',modules{k});end %#ok<AGROW>
for k=1:numel(directories)
 folder=directories{k};
 if isfolder(folder)&&~contains([path pathsep],[folder pathsep]),addpath(folder,'-end');end
end
lastPath=path;
end
