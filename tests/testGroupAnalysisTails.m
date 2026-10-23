function tests=testGroupAnalysisTails
% Run with runtests('tests/testGroupAnalysisTails.m').
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
testCase.TestData.a=[5;7;9;11;14];testCase.TestData.b=[1;2;4;3;6];
testCase.TestData.groups=[repmat({'PACAP'},5,1);repmat({'Control'},5,1)];
S=struct('testType','Two-sample t-test (Student, equal var)','alpha',.05, ...
    'colorMode','Scheme','manualGroupA','PACAP','manualGroupB','Control');
testCase.TestData.settings=S;
T=repmat({''},10,8);T(:,3)=testCase.TestData.groups;
for k=1:10,T{k,2}=sprintf('Animal%d',k);T{k,5}=sprintf('pair%d',mod(k-1,5)+1);end
testCase.TestData.rows=T;
end

function testTailsAndConfidenceIntervalsMatchMATLAB(testCase)
assumeTrue(testCase,exist('ttest2','file')==2&&exist('ttest','file')==2);
a=testCase.TestData.a;b=testCase.TestData.b;S=testCase.TestData.settings;
groups=testCase.TestData.groups;rows=testCase.TestData.rows;
types={'Two-sample t-test (Student, equal var)','Two-sample t-test (Welch)', ...
    'Paired t-test (matched PairID / animal)','One-sample t-test (vs 0)'};
for kind=1:numel(types)
    S.testType=types{kind};values=[a;b];g=groups;T=rows;
    if kind==4,values=a;g=g(1:5);T=T(1:5,:);end
    for alpha=[.05 .2 .6]
        S.alpha=alpha;
        for tail={'both','right','left'}
            S.testTail=tail{1};actual=GroupAnalysis_Common('computeStats',values,g,S,T);
            if kind==1,[~,p,ci,st]=ttest2(a,b,'Vartype','equal','Tail',tail{1},'Alpha',alpha);
            elseif kind==2,[~,p,ci,st]=ttest2(a,b,'Vartype','unequal','Tail',tail{1},'Alpha',alpha);
            elseif kind==3,[~,p,ci,st]=ttest(a,b,'Tail',tail{1},'Alpha',alpha);
            else,[~,p,ci,st]=ttest(a,0,'Tail',tail{1},'Alpha',alpha);end
            verifyEqual(testCase,actual.p,p,'AbsTol',1e-12);
            verifyEqual(testCase,actual.t,st.tstat,'AbsTol',1e-12);
            verifyEqual(testCase,actual.ci,ci(:)','AbsTol',1e-10);
        end
    end
end
end

function testDirectionAndLegacyDefault(testCase)
S=testCase.TestData.settings;S.testTail='right';
x=[testCase.TestData.a;testCase.TestData.b];g=testCase.TestData.groups;T=testCase.TestData.rows;
right=GroupAnalysis_Common('computeStats',x,g,S,T);
S.testTail='left';left=GroupAnalysis_Common('computeStats',x,g,S,T);
verifyLessThan(testCase,right.p,.05);verifyGreaterThan(testCase,left.p,.95);
verifyEqual(testCase,right.p+left.p,1,'AbsTol',1e-12);
order=[10 3 7 1 6 2 8 4 9 5];S.testTail='right';
reordered=GroupAnalysis_Common('computeStats',x(order),g(order),S,T(order,:));
verifyEqual(testCase,reordered.p,right.p,'AbsTol',1e-12);
verifyEqual(testCase,reordered.alternative,'PACAP > Control');
legacy=GroupAnalysis_Common('computeStats',x,g,rmfield(S,'testTail'),T);
verifyEqual(testCase,legacy.p,2*right.p,'AbsTol',1e-12);
verifyEqual(testCase,legacy.tail,'two-sided');
S.testType='One-way ANOVA (groups)';right=GroupAnalysis_Common('computeStats',x,g,S,T);
S.testTail='left';left=GroupAnalysis_Common('computeStats',x,g,S,T);
verifyEqual(testCase,right.p,left.p);verifyEqual(testCase,left.tail,'upper (F)');
end

function testExcelKeepsUnboundedConfidenceInterval(testCase)
S=testCase.TestData.settings;S.testTail='right';
r=GroupAnalysis_Common('computeStats',[testCase.TestData.a;testCase.TestData.b], ...
    testCase.TestData.groups,S,testCase.TestData.rows);
R=struct('stats',r,'metricName','Fixed interval mean');
C=GroupAnalysis_Common('buildROIStatisticsSheetForExcel',R);
verifyEqual(testCase,C{strcmp(C(:,1),'Alternative hypothesis'),2},'PACAP > Control');
verifyEqual(testCase,C{strcmp(C(:,1),'CI upper'),2},'Inf');
file=[tempname '.xlsx'];cleanup=onCleanup(@()delete(file)); %#ok<NASGU>
writecell(C,file);actual=readcell(file);
verifyEqual(testCase,actual{strcmp(actual(:,1),'CI upper'),2},'Inf');
end
