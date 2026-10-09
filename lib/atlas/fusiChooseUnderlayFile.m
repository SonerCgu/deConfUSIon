function [file,options]=fusiChooseUnderlayFile(par,root,transformFile,lastFile,dialogFcn)
% Use one file filter and an explicit full initial path in both viewers.
if nargin<5 || isempty(dialogFcn),dialogFcn=@uigetfile;end
options=fusiUnderlayPickerOptions(par,root,transformFile,lastFile);
[name,folder]=dialogFcn(options.filter,options.title,options.defaultFile);
file='';if isequal(name,0),return;end
file=fullfile(folder,name);
end
