function fusiRememberDataRoot(file)
% Remember only explicitly opened project roots, for moved cross-platform paths.
if ~(ischar(file)||(isstring(file)&&isscalar(file))),return;end
file=strrep(char(file),'\','/');
cut=regexp(file,'/(RawData|AnalysedData)(?=/|$)','start','once','ignorecase');
if isempty(cut),return;end
root=strrep(file(1:cut-1),'/',filesep);if ~isfolder(root),return;end
root=char(java.io.File(root).getCanonicalPath());
roots=getpref('deConfUSIon','dataRoots',{});if ischar(roots),roots={roots};end
roots=[{root} roots];roots=unique(roots,'stable');roots=roots(1:min(8,numel(roots)));
setpref('deConfUSIon','dataRoots',roots);
end
