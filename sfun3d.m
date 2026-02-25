function sfun3d(block,varargin)

%   This is an S-function for a block that acts as an X-Y-Z scope for
%   multiple point-like objects that change their position in time.
%
%   NOTE: For MATLAB versions before 2014b, download a previous version
%   that uses the S-function sfunxyz.m.
%
%   See also sfunxy2.

%   Copyright 2026 The MathWorks, Inc.
%   Based on original work by Andy Grace (May-91), Wes Wang (Apr-93, Aug-93,
%   Dec-93), Craig Santos (Oct-96), and Giampiero Campa (Apr-04, Nov-15,
%   Jan-17, Nov-17, Feb-26).

if nargin == 1
    setup(block)
else
    % These calls are defined in the Properties -> Callbacks
    % section of the S-Function block.
    switch varargin{end}
        case 'NameChange'
            LocalBlockNameChangeFcn
        case { 'CopyBlock', 'LoadBlock' }
            LocalBlockLoadCopyFcn
        case 'DeleteBlock'
            LocalBlockDeleteFcn
    end
end
end

%%
function setup(block)

% Version check
vrs=version;
if str2double(vrs(1:3))<8.4
    error(['This S-Function (sfun3d.m) works only within MATLAB versions 2014b and later.' newline ...
        'For older MATLAB versions, install a previous block version based on the S-function sfunxyz.m instead.']);
end

% Setup functional port properties to dynamically inherited.
block.SetPreCompInpPortInfoToDynamic;

% Register number of block parameters.
block.NumDialogPrms  = 10;

%% Get all parameters

% Get axis.
ax = block.DialogPrm(1).Data;
validateattributes(ax,{'numeric'},{'finite','size',[1 6]});

% Get and register sample time.
block.SampleTimes = [block.DialogPrm(2).Data 0];

% Get number of moving points (i.e. number of lines) to be plotted.
nmax = fix(block.DialogPrm(3).Data);
validateattributes(nmax,{'numeric'},{'finite','nonnegative','size',[1 1]});

% Get camera position and grid switch.
CPos = block.DialogPrm(4).Data;
validateattributes(CPos,{'numeric'},{'finite','size',[1 3]});
if block.DialogPrm(5).Data, GdSw='On'; else GdSw='Off'; end

% Get LineStyle and Marker character vectors.
ls = block.DialogPrm(6).Data; if isempty(ls), ls='-'; end
mk = block.DialogPrm(7).Data; if isempty(mk), mk='none'; end

% Get maximum number of points for each line.
mx = fix(block.DialogPrm(8).Data);
validateattributes(mx,{'numeric'},{'finite','positive','size',[1 1]});

% Get the header marker parameter.
hd = block.DialogPrm(9).Data; if isempty(hd), hd=false; end

% Get the active figure parameter (toolbar and menubar).
if block.DialogPrm(10).Data, tb='figure'; else tb='none'; end

%% Initialize figure.
FigHandle=get_param(gcbh,'UserData');
if isempty(FigHandle) || ~ishandle(FigHandle)
    % The figure doesn't exist, create one.
    FigHandle = figure(...
        'Units',          'pixel',...
        'Position',       [100 100 400 300],...
        'Name',           get_param(gcbh,'Name'),...
        'Tag',            'SIMULINK_3DGRAPH_FIGURE',...
        'NumberTitle',    'off',...
        'IntegerHandle',  'off',...
        'Toolbar',        tb,...
        'Menubar',        tb);
else
    % Otherwise clear it.
    clf(FigHandle);
end

% Note: the structure pd contains all the plot data and will be
% later stored in the figure's userdata!

% Create axes.
pd.XYZAxes = axes('Parent',FigHandle);
cord=get(pd.XYZAxes,'ColorOrder');
set(pd.XYZAxes,'Visible','on','Xlim', ax(1:2),'Ylim', ax(3:4),'Zlim', ax(5:6),'CameraPosition',CPos,'XGrid',GdSw,'YGrid',GdSw,'ZGrid',GdSw);

% Create a vector of animatedline objects.
pd.XYZLine = [];
for n=1:nmax
    pd.XYZLine = [pd.XYZLine animatedline('Parent',pd.XYZAxes,'LineStyle',ls,'Marker',mk,'MaximumNumPoints',mx,'Color',cord(1+mod(n-1,size(cord,1)),:))];
end

% Create a vector of line objects that represents the header position.
if hd
    pd.XYZHead = [];
    mrks={'o';'square';'diamond';'v';'+';'*';'x';'^';'>';'<';'pentagram';'hexagram'};
    for n=1:nmax
        pd.XYZHead = [pd.XYZHead line('Parent',pd.XYZAxes,'Marker',mrks{1+mod(n-1,size(mrks,1))},'Color',cord(1+mod(n-1,size(cord,1)),:))];
    end
end

% Create axis labels.
xlabel('X Axis');ylabel('Y Axis');zlabel('Z Axis');

% Create plot title.
pd.XYZTitle  = get(pd.XYZAxes,'Title');
set(pd.XYZTitle,'String','X Y Z Plot');

% Store pd so it can be later retrieved at runtime.
set(FigHandle,'UserData',pd); % Store pd in figure's userdata.
set_param(gcbh,'UserData',FigHandle); % Store figure handle in block's UserData.

% Register the number input port number and size at runtime.
block.NumInputPorts  = 1;
block.InputPort(1).Dimensions = 3*nmax;

% Register the number output ports at runtime.
block.NumOutputPorts  = 0;

% Register the update method.
block.RegBlockMethod('Update', @Update);
end

%%
function Update(block)

% Get figure handle.
FigHandle=get_param(gcbh,'UserData');
if isempty(FigHandle) || ~ishandle(FigHandle), return, end

% Get plot data structure.
pd = get(FigHandle,'UserData');

% Get inputs.
u = block.InputPort(1).Data;

% Add points to each line.
nmax=length(pd.XYZLine);
for i=1:nmax
    addpoints(pd.XYZLine(i),u(3*(i-1)+1),u(3*(i-1)+2),u(3*(i-1)+3));
end

% Get the header marker parameter.
hd = block.DialogPrm(9).Data; if isempty(hd), hd=false; end

% Update head position.
if hd
    for i=1:nmax
        set(pd.XYZHead(i),'xdata',u(3*(i-1)+1),'ydata',u(3*(i-1)+2),'zdata',u(3*(i-1)+3));
    end
end
end

%%
function LocalBlockDeleteFcn
% Remove association between figure and block.
FigHandle=get_param(gcbh,'UserData');
if ishandle(FigHandle)
    delete(FigHandle);
    set_param(gcbh,'UserData',-1)
end
end

%%
function LocalBlockNameChangeFcn
% Get the figure associated with this block,
% if it's valid, change the name of the figure.
FigHandle=get_param(gcbh,'UserData');
if ishandle(FigHandle)
    set(FigHandle,'Name',get_param(gcbh,'Name'));
end
end

%%
function LocalBlockLoadCopyFcn
% Remove association between figure and block.
set_param(gcbh,'UserData',-1);
end
