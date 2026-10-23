function folder=fusiLightSuiteChooseAtlasProject(folder,choose)
% Resolve an explicitly requested atlas folder without hiding saved revisions.
if nargin<2,choose=@listdlg;end
root=char(folder);candidates={};names={};times=[];
add(root,'Original project');
revisions=dir(fullfile(root,'Registration_*'));revisions=revisions([revisions.isdir]);
for k=1:numel(revisions),add(fullfile(root,revisions(k).name),revisions(k).name);end
if isempty(candidates),return;end
if numel(candidates)==1,folder=candidates{1};return;end
[~,initial]=max(times);
[index,ok]=choose('PromptString',{'Choose the saved registration to load.', ...
    'The original project and each revision contain different fits.'}, ...
    'Name','LightSuite registration version','SelectionMode','single', ...
    'ListString',names,'InitialValue',initial,'ListSize',[680 190]);
folder='';if ok&&isscalar(index)&&index>=1&&index<=numel(candidates),folder=candidates{index};end
    function add(path,label)
        regions=fullfile(path,'LightSuite_Native_Regions.mat');
        if ~isfile(regions),return;end
        fit=dir(fullfile(path,'transform_params.mat'));if isempty(fit),fit=dir(regions);end
        count='';cp=fullfile(path,'control_points_minimal.mat');
        if isfile(cp)
            try
                points=load(cp,'sample_points');a=points.sample_points;
                n=size(a,1);if iscell(a),n=sum(cellfun(@(x)size(x,1),a));end
                count=sprintf(' | %d landmarks',n);
            catch
            end
        end
        candidates{end+1}=path;times(end+1)=fit.datenum; %#ok<AGROW>
        names{end+1}=sprintf('%s | fit %s%s',label,datestr(fit.datenum,'dd-mmm-yyyy HH:MM'),count); %#ok<AGROW>
    end
end
