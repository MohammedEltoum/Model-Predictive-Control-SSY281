%  Write a code that does the simulation and plots the system output and
%  input with respect to time.
% Your plots should have meaningful labels and simulates the system after
% the convergence to the final set as well to shows the system remains in
% it. Explain the concept that you have used to design the controller in
% your report, provide the simulation outcomes, and explain your
% observations.


%% Model parameters

clear;close all;clc;yalmip('clear');

LS = 1;
dS = 0.02;
JM = 0.5;
betaM = 0.1;
R = 20;
kT = 10;
rho = 20;
kth = 1280.2;
JL = 50*JM;
betaL = 25;

% Continuous time state-space matrices
Ac = [0 1 0 0;
     -kth/JL -betaL/JL kth/(rho*JL) 0;
     0 0 0 1;
     kth/(rho*JM) 0 -kth/(rho^2*JM) -(betaM+kT^2/R)/JM];
Bc = [0 0 0 kT/(R*JM)].';
Cc = [kth 0 -kth/rho 0];

% Sampling time
dt = 0.1;
dt = min(dt, pi/max(damp(Ac)));    % [s]

% Convert to discrete time
sys=ss(Ac,Bc,Cc,0);
sysd=c2d(sys,dt);
A = sysd.A;
B = sysd.B;
C = sysd.C;

% size of problem to be solved
nx = size(A, 2);
nu = size(B,2);

% input and output constraints (lower and upper bound)
T_b = [-157 157];
V_b = [-200 200];


%% Create MPC model
plotP = @(Pol) plot(projection(Pol,[2 4]));

% MPC parameters
Q=eye(nx); 
R=1;
Nmax = 30;

% initial state
x0 = [0 2.5 0 75]';

X = Polyhedron('A',[C;-C],'B',[T_b(2); -T_b(1)]);
U = Polyhedron('lb',V_b(1),'ub',V_b(2));

xsdp = sdpvar(nx, 1)
% Xf = Polyhedron( [-0.1<=xsdp([2,4])<=0.1 ;-Inf<=xsdp([1,3])<=Inf ] ); %
Xf = Polyhedron( [-0.1<=xsdp([2,4])<=0.1 ;-Inf<=xsdp([1,3])<=Inf ] ); %

% define model
model = LTISystem('A', A, 'B', B, 'C', C);
model.x.with('setConstraint');
model.x.setConstraint = Polyhedron('A',[C;-C],'b',[T_b(2) -T_b(1)]);
model.u.min = V_b(1);
model.u.max = V_b(2);
model.x.penalty = QuadFunction(Q);
model.u.penalty = QuadFunction(R);
model.x.with('terminalSet');
model.x.terminalSet = Xf;
% mintime = EMinTimeController(model)

K = Xf;
isin = false; iN = 0;
while ~isin
    iN = iN+1
    K(iN+1) = model.reachableSet('X', K(iN), 'U', U, 'N', 1, 'direction', 'backward');
    isin =  all(K(end).A*x0-K(end).b <= 0);
end
% plotP(K(end))

isin = false;
K(1) = Xf;
for i=1:iN
    K(i+1) = model.reachableSet('X', K(i), 'U', U, 'N', 1, 'direction', 'backward');
    
    % optimization variables
    x = sdpvar(nx, 1);
    u0 = sdpvar(nu, 1);
    
    % cost function
    J = u0'*R*u0 + (A*x + B*u0)'*Q*(A*x + B*u0);

    % constraints
    con = [ T_b(1) <= C*x <= T_b(2);           % x0 \in X
            V_b(1) <= u0   <= V_b(2);           % u0 \in U
            K(i).A*(A*x + B*u0) <= K(i).b      % x1 \in Pre^{i-1}(Xf)
            ];
        
%     figure; plot(projection(Polyhedron(con),[2 4]))
%     figure; plot(projection(Polyhedron(con),[1 3]))
        
    [sol,diagnostics,aux,Valuefunction,Optimal_z] = solvemp(con, J, [], x, u0)
    plp = Opt(con, J, x, u0);
    solution = plp.solve()


%     plot(Valuefunction);
%     figure
%     plot(Optimal_z);
    if isempty(sol{1})
        error('Empty parametric solution');
        return;
    end

    [isin,j] = isinside(sol{1}.Pn,x0);
    if isin
        sol{1}.Fi{j}*x0 + sol{1}.Gi{j};
    end
end








