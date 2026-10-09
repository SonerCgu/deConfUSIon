function [names,files,selected,groupings]=fusiAtlasUnderlayChoices(file)
% Switch only within the explicitly loaded registration's dated bundle.
names={};files={};selected=1;groupings={};
if isempty(file)||~isfile(file),return;end
folder=fileparts(file);
options={'Histology','Histology.mat';'Vascular','Vascular.mat'; ...
 'Regions: all','Regions_All.mat';'Regions: merged','Regions_Merged.mat'};
for k=1:size(options,1)
 f=fullfile(folder,options{k,2});
 if ~isfile(f)&&k>=3,f=fullfile(folder,'Regions.mat');end
 if ~isfile(f),continue;end
 names{end+1}=options{k,1};files{end+1}=f; %#ok<AGROW>
 grouping='';if k==3,grouping='Detailed';elseif k==4,grouping='Parent';end
 groupings{end+1}=grouping; %#ok<AGROW>
 if strcmpi(f,file),selected=numel(files);end
end
end
