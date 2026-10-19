function [out, stats] = despike(data, zthr, saveRoot, tag)

% ==========================================================
% VOXEL-WISE MAD DESPIKING (STABLE VERSION)
% ==========================================================

deConfUSIon_setup();
if nargin < 2 || isempty(zthr)
    zthr = 5;
end

if nargin < 4 || isempty(tag)
    tag = datestr(now,'yyyymmdd_HHMMSS');
end

if nargin < 3 || isempty(saveRoot)
    saveRoot = pwd;
end

data = single(data);
sz = size(data);

if ndims(data) == 3
    Y = sz(1); X = sz(2); T = sz(3);
    Z = 1;
    data4D = reshape(data,Y,X,1,T);
elseif ndims(data) == 4
    Y = sz(1); X = sz(2); Z = sz(3); T = sz(4);
    data4D = data;
else
    error('Data must be 3D or 4D.');
end

flat = reshape(data4D,[],T);
progress=deConfUSIon_ui('progress','Motion correction - despiking');
progressGuard=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>

totalPoints = numel(flat);

[flat,spikesPerFrame,spikeCounts] = fusiDespikeVoxels(flat,zthr, ...
    @(fraction)deConfUSIon_ui('progressupdate',progress,.95*fraction, ...
    'Detecting and interpolating voxel spikes'));
removedPoints = sum(double(spikeCounts));
spikeMap = reshape(spikeCounts,Y,X,Z);

out = reshape(flat,Y,X,Z,T);
if numel(sz)==3, out=reshape(out,sz); end
deConfUSIon_ui('progressupdate',progress,.95,'Saving despiking QC');

% =========================
% STATS
% =========================
stats.totalPoints = totalPoints;
stats.removedPoints = removedPoints;
stats.percentRemoved = 100 * removedPoints / totalPoints;
stats.zThreshold = zthr;

% =========================
% QC FIGURE
% =========================
qcFolder = fullfile(saveRoot,'Preprocessing','QC_despike');
if ~exist(qcFolder,'dir')
    mkdir(qcFolder);
end

qcFile = fullfile(qcFolder,['QC_despike_' tag '.png']);

fig = figure('Visible','off','Color','w','Position',[200 200 1200 800]);

subplot(3,1,1)
plot(spikesPerFrame,'k','LineWidth',1)
title('Spikes per frame')
xlabel('Frame')
ylabel('# spikes')
grid on

subplot(3,1,2)
hist(spikesPerFrame,50)
title('Distribution of spikes per frame')
xlabel('# spikes')
ylabel('Count')

subplot(3,1,3)
midSlice = round(Z/2);
imagesc(spikeMap(:,:,midSlice))
colorbar
title('Spike spatial map (mid slice)')
xlabel('X')
ylabel('Y')

annotation('textbox',[0 0.95 1 0.04],...
    'String','Voxel-wise MAD Despiking QC',...
    'EdgeColor','none',...
    'HorizontalAlignment','center',...
    'FontWeight','bold');

saveas(fig,qcFile);
close(fig)

stats.qcFile = qcFile;

clear flat spikeMap spikesPerFrame
drawnow

end
