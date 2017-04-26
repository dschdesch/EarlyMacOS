function [H,G] = AOISI(D,figh,P)
% dataset/AOISI - (all order) inter spike interval histogram of a dataset
%    AOISI(D) calculates shifted autocorrelogram for the spike times in
%    dataset D.
%
%    AOISI(D,figh) uses figure handle figh for plotting
%    (default = [] -> gcf). 
%
%    AOISI(D,figh,P) uses parameters P for displaying the FOISI.
%    P is typically a dataviewparam object or a valid 2nd input argument to
%    the dataviewparam constructor method, such as a parameter filename.
%
%    AOISI is a standard "dataviewer", meaning that it may serve as
%    viewer for online data analysis during data collection. In addition,
%    the plot generated by all dataviewers allow an interactive change of
%    analysis parameter view the Params|Edit pullodwn menu (Ctr-Q).
%    For details on dataviewers, see dataviewparam.
%
%    See also dataviewparam, dataset/enableparamedit.

% Handle the special case of parameter queries. 
% Do this immediately to avoid endless recursion with dataviewparam.
if isvoid(D) && isequal('params', figh),
    [H,G] = local_ParamGUI;
    return;
end

% Should we open a new figure or use an existing one?
if nargin<2 || isempty(figh),
    open_new = isempty(get(0,'CurrentFigure'));
    figh = gcf; 
else
    open_new = isSingleHandle(figh);
end

% Parameters
if nargin<3, P = []; end
if isempty(P), % use default paremeter set for this dataviewer
    P = dataviewparam(mfilename); 
end

% delegate the real work to local fcn
local_AOISI(D, figh, open_new, P);

% enable parameter editing when viewing offline
if isSingleHandle(figh, 'figure'), enableparamedit(D, P, figh); end;



%============================================================
%============================================================
function local_AOISI(D, figh, open_new, P);
% the real work for the shifted autocorrelogram
if isSingleHandle(figh, 'figure')
    figure(figh); clf; ah = gca;
    if open_new, placefig(figh, mfilename, D.Stim.GUIname); end % restore previous size 
else
    ah = axes('parent', figh);
end

% Check varied stimulus Params
Pres = D.Stim.Presentation;
P = struct(P); P = P.Param;
isortPlot = P.iCond(P.iCond<=Pres.Ncond); % limit to actual Ncond
if isortPlot==0, isortPlot = 1:Pres.Ncond; end;
Ncond = numel(isortPlot);
AW = P.Anwin;
% maxDelay = P.maxDelay;
maxDelay = 5;
if isequal(P.scaling,'constrained'), doScale = 1; else doScale = 0; end;
% XXXXXX

% prepare plot
Clab = cellify(CondLabel(D));
[axh, Lh, Bh] = plotpanes(Ncond+1, 0, figh);

% get sorted spikes
Chan = 1; % digital input
TC = spiketimes(D, Chan, 'no-unwarp');

H = zeros(Ncond, P.Nbin);
isortPlot=isortPlot(:).';
for i=1:Ncond
    icond = isortPlot(i);
    BurstDur = max(burstdur(D,icond));
    if isequal('burstdur', AW), aw = [0 BurstDur]; else aw = AW; end;
    if maxDelay==0, maxDelay = 5; end;
    BinEdges = linspace(0, maxDelay, P.Nbin+1); % hisotgram bins
    BinWidth = BinEdges(2)-BinEdges(1);
    BinCenters = BinEdges(1:(end-1))+(BinWidth/2);
    spt = sort([TC{icond,:}]); % spike times of condition icond sorted in ascending order
    N = local_autocorr(BinEdges, spt, aw);
    for irep=1:Pres.Nrep % subtract within-rep terms
        N = N - local_autocorr(BinEdges, sort(TC{icond,irep}), aw);
    end
    H(i,:) = N;
    h = axh(i); % current axes handle
    % axes(h); % Slowdown!!!!
    bar(h, BinCenters, N, 'histc');
    xlim(h, [0 maxDelay]) % Plot to 5ms 
    title(h, Clab{icond});
end
% we can only scale now
if doScale
    maxy = max(H(:));
    for i=1:Ncond
        h = axh(i);
        ylim(h, [0 maxy]);
    end
end
Xlabels(Bh,'delay (ms)','fontsize',10);
Ylabels(Lh,'statistical frequency','fontsize',10);
% axes(axh(end)); 
set(gcf,'CurrentAxes',axh(end));
text(0.1, 0.5, IDstring(D, 'full'), 'fontsize', 12, 'fontweight', 'bold','interpreter','none');
if nargout<1, clear H ; end % suppress unwanted echoing

function N = local_autocorr(BinEdges, Spt, Anwin)
Spt = AnWin(Spt, Anwin); % apply analysis window
DiffSpt = ones(length(Spt),1)*Spt(:)' - Spt(:)*ones(1,length(Spt)); % ISIs in upper right part are always > 0;
DiffSpt = triu(DiffSpt);
DiffSpt = DiffSpt(find(DiffSpt)); % linearized and nonzero
if isempty(DiffSpt), DiffSpt = Inf; end; % to avoid crash dump but still use histc
N = histc(DiffSpt, BinEdges);
N(end) = []; % remove last garbage bin
N = N(:);

function [T,G] = local_ParamGUI
% Returns the GUI for specifying the analysis parameters.
P = GUIpanel('AOISI','');
iCond = ParamQuery('iCond', 'iCond:', '0', '', 'integer',...
    'Condition indices for which to calculate the ISI correlogram. 0 means: all conditions.', 20);
Nbin = ParamQuery('Nbin', '# bins:', '50', '', 'posint',...
    'Number of bins used for computing the ISI correlogram.', 1);
Anwin = ParamQuery('Anwin', 'analysis window:', 'burstdur', '', 'anwin',...
    'Analysis window (in ms) [t0 t1] re the stimulus onset. The string "burstdur" means [0 t], in which t is the burst duration of the stimulus.');
maxDelay = ParamQuery('maxDelay', 'max delay:', 'burstdur', '', 'integer',...
    'Maximum delay (in ms) considered in computing the autocorrelation. 0 means: t, in which t is the burst duration of the stimulus.',1);
scaling = ParamQuery('scaling','scaling:','',{'auto','constrained'},'',...
    'Click to toggle between histogram scaling options.', 20);
% ParamOrder = ParamQuery('ParamOrder', 'param order:', '', {'[1 2]','[2 1]'}, 'posint',...
%     'Order of independent parameters when sorting [1 2] = "Fastest varied" = "Fastest varied". [2 1] = conversely.', 10);
% SortOrder = ParamQuery('SortOrder', 'sorting order:', '0 0', '', 'integer',...
%     'Sorting order of corresponding independent parameters. (-1,0,1)=(descending, as visited, ascending)',10);
P = add(P, iCond);
P = add(P, Nbin, below(iCond));
P = add(P, Anwin, below(Nbin));
P = add(P, maxDelay, below(Anwin));
P = add(P, scaling, below(maxDelay));
% P = add(P, ParamOrder, below(Anwin));
% P = add(P, SortOrder, below(ParamOrder));
P = marginalize(P,[4 4]);
G = GUIpiece([mfilename '_parameters'],[],[0 0],[10 10]);
G = add(G,P);
G = marginalize(G,[10 10]);
% list all parameters in a struct
T = VoidStruct('iCond/Nbin/Anwin/maxDelay/scaling');