function test_group_roi_metrics
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
out=fullfile(root,'validation','group_roi'); if ~exist(out,'dir'), mkdir(out); end
t=0:1/60:12; y=4*ones(size(t)); y(t>=7&t<=8)=10;
p=GroupAnalysis_Common('robustPeak',y,t,6,9,1,10);
assert(abs(p-10)<1e-10);
y(round(7.5*60)+1)=10000;
assert(abs(GroupAnalysis_Common('robustPeak',y,t,6,9,1,10)-10)<1e-10);
assert(isnan(GroupAnalysis_Common('robustPeak',y,t,6,6.5,1,10)));
sparse=nan(size(t)); sparse(round(7.5*60)+1)=10000;
assert(isnan(GroupAnalysis_Common('robustPeak',sparse,t,6,9,1,10)));
[v,c]=GroupAnalysis_Common('plateauMean',2*t+1,t,6,9);
assert(abs(v-16)<1e-10 && c==1);
assert(isnan(GroupAnalysis_Common('plateauMean',ones(1,481),t(1:481),6,9)));
% Dense unsmoothed data, a gap, and a truncated SEM tail.
f=figure('Visible','off'); cleaner=onCleanup(@()close(f)); ax=axes('Parent',f);
tt=linspace(0,20,24001); yy=sin(13*tt)+.1*cos(91*tt); ee=.3+0*tt;
ee(tt>17 | (tt>7 & tt<8))=NaN;
h=GroupAnalysis_Common('drawSEM',ax,tt,yy,ee,[0 .5 .9],.35);
faces=get(h,'Faces'); vertices=get(h,'Vertices');
assert(~isempty(faces) && all(all(isfinite(vertices(faces(:),:)))));
xx=reshape(vertices(faces(:,1),1),[],1);
assert(~any(xx>7 & xx<8) && ~any(xx>17));
hold(ax,'on'); plot(ax,tt,yy); print(f,fullfile(out,'unsmoothed_sem.png'),'-dpng','-r120');
% Launch actual group GUI to obtain complete defaults and exercise real ROI analysis.
old=get(groot,'DefaultFigureVisible'); set(groot,'DefaultFigureVisible','off');
restore=onCleanup(@()set(groot,'DefaultFigureVisible',old));
gui=GroupAnalysis('startDir',out); closeGui=onCleanup(@()delete(gui)); S=guidata(gui);
assert(S.tc_peakSearchMin0==6 && S.tc_peakSearchMin1==9 && S.tc_peakWinMin==1);
assert(strcmp(get(S.hPrevXMax,'String'),'20'));
cache=struct('roiTC',containers.Map('KeyType','char','ValueType','any'));
subj=cell(4,9); base=sin(t)+10;
for i=1:4
    nm=sprintf('subject%d',i); group='A'; if i>2, group='B'; end
    ti=t; yi=base+i;
    if i==2, yi=yi(ti<=8); ti=ti(ti<=8); end
    subj(i,:)={true,nm,group,'condition',nm,'',nm,'',''};
    cache.roiTC(['ROI||||' nm])=struct('tc',yi,'tMin',ti,'isPSCInput',true);
end
[R,~]=GroupAnalysis_Common('runROITimecourseAnalysis',S,subj,cache);
assert(all(isnan(R.group(1).sem(R.tMin>8))));
assert(max(abs(R.group(1).sem(R.tMin<7)-.5))<1e-10);
assert(isequal(size(R.metrics.table),[5 6]) && all(isfinite(R.metricVals)));
S.lastROI=R; S.tc_previewSmooth=false;
GroupAnalysis_Common('exportOnePreview',ax,1,S,'Light');
assert(~isempty(findobj(ax,'Tag','GroupROI_SEM')));
before=R.metricVals; S.tc_previewSmooth=true;
GroupAnalysis_Common('exportOnePreview',ax,1,S,'Light');
[R2,~]=GroupAnalysis_Common('runROITimecourseAnalysis',S,subj,cache);
assert(isequaln(before,R2.metricVals));
S.tc_metric='Plateau'; [RP,~]=GroupAnalysis_Common('runROITimecourseAnalysis',S,subj,cache);
assert(isnan(RP.metricVals(2)) && RP.plateauCoverage(2)<.8);
save(fullfile(out,'roi_result.mat'),'R','RP');
fprintf('PASS: unsmoothed SEM, gaps, singleton tails, peak outlier resistance, coverage, GUI defaults, analysis and result schema.\n');
end
