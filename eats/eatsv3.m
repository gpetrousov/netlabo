function [averageQtime, Throughput, drop_perc] = eatsv3( Sim_Time, Nodes, Channels, Queue_Size, Lambda, Packet_Size)

if Nodes < Channels
    error('use more stations than channels')
end
if Nodes == 0
    error('zero nodes wtf...')
end
if Channels == 0
    error('how am i suppose to send packets with no channels?')
end

flag=true;
T=0;
Event_List=zeros(3, 2 * Nodes + 2);
Event_List(1,1:Nodes)=1; % Arrival Event
Event_List(2,1:Nodes)=0; % generate packets time 0
Event_List(3,1:Nodes)=1:Nodes;

Event_List(1, Nodes + 1:2 * Nodes) = 2; %control event
Event_List(2, Nodes + 1:2 * Nodes) = (1/4) * (1 : Nodes);
Event_List(3, Nodes + 1:2 * Nodes) = 1:Nodes; %for each node

Event_List(1, 2 * Nodes + 1) = 3; %just a checking event 
Event_List(2, 2 * Nodes + 1) = Nodes * 0.25;

Event_List(1,end)=10; % Simulation End Event
Event_List(2,end)=Sim_Time;

index = zeros(Nodes, Queue_Size);
Q1=zeros(Nodes,Queue_Size);
Q2=zeros(Nodes,Queue_Size);
Q1(1:Nodes, 1:Queue_Size) = -1;
Sending_list = zeros(Channels + 1, 1);
Senders_list = zeros(Channels, 1);
D = zeros(Nodes, Nodes);
drop_packets=0;
total_packets=0;
sent_packets = 0;
Qtime = 0;

Throughput=0;

RAT = zeros(1, Nodes);
CAT = zeros(1, Channels);
sync_time = 1;
Rtt = 2;
%disp('Channels')
%disp(Sending_list)
%disp('event_list')
%disp(Event_List)

while flag
    event=Event_List(1,1);
    %fprintf('time %d\n', Event_List(2,1));
    
    if event==1 %packet arrive    
        [T,Event_List,Q1,Q2,total_packets,drop_packets]=Event1(T,Event_List,Lambda,Q1,Q2,total_packets,drop_packets, Queue_Size, Nodes);
       
    elseif event==2        
        [T,Event_List, Sending_list, CAT, RAT, D, Senders_list, index]=Event2(T,Event_List, Sending_list, Q1, Q2, CAT, RAT, Channels, sync_time, Rtt, D, Nodes, Senders_list, index, Queue_Size);
    
    elseif event == 3 %check for  packets
        [T, Event_List] = Event3(T, Event_List, Sending_list, Senders_list, Channels, Nodes, Q1, Q2);
        
    elseif event == 4
        [T, Event_List, Sending_list, Senders_list, Q1, Q2, index, CAT, RAT, Qtime, sent_packets] = Event4(T, Event_List, Sending_list, Senders_list, Q1, Q2, Channels, Queue_Size, index, CAT, RAT, Qtime, sent_packets);
        
    elseif event==10
        [T,flag]=Event10(T,flag,Event_List);
        
    end
    
    Event_List(:,1)=[];
    Event_List=(sortrows(Event_List',[2,1]))';
    
end
%SIMULATION END%
fprintf('\n');
drop_packet_perc = (drop_packets * 100) / total_packets;
disp('simulation end')
fprintf('total packets %d\n', total_packets);
fprintf('successfully sent packets %d\n', sent_packets);
fprintf('packets dropped %d\n', drop_packets);
fprintf('packets left in queue %d\n', total_packets - sent_packets - drop_packets);
fprintf('drop packets percentage %.2f%%\n', (drop_packets * 100) / total_packets );
drop_perc = (drop_packets * 100) / total_packets;
fprintf('Throughput %.2f Bps\n', (Packet_Size * sent_packets)/Sim_Time); %Bytes
Throughput = (Packet_Size * sent_packets)/Sim_Time;
fprintf('total queue time %.4f\n', Qtime);
fprintf('average queue time %.4f\n', Qtime / sent_packets);
averageQtime = Qtime / sent_packets;
end

function [T,Event_List,Q1,Q2,total_packets,drop_packets]=Event1(T,Event_List,Lambda,Q1,Q2,total_packets,drop_packets, Queue_Size, Nodes)
%disp('event 1:')
T=Event_List(2,1);
%fprintf('time %f\n',T);
%disp('Q before')
%Q1
%Q2
total_packets=total_packets+1;
counter=1;
drop_flag=true;

while(counter<=Queue_Size)
    if Q1(Event_List(3,1),counter)== -1 && Q2(Event_List(3, 1), counter) == 0 %there is spot in senders queue
        %disp('got queue')    
        Q1(Event_List(3,1),counter)= T; %when the packet will be sent
        destination_node = randi(Nodes);
        %fprintf('sender %d\n', Event_List(3,1));
        while destination_node == Event_List(3,1)
            destination_node=randi(Nodes);
        end
        %fprintf('reciever %d\n', destination_node);
        Q2(Event_List(3,1),counter)=destination_node; %where the packet will be sent to
        drop_flag=false;
        break;
    end
    counter=counter+1;
end
if drop_flag==true
    drop_packets=drop_packets+1;
    %disp('packet drop')
end
%disp('Q after')
%Q1
%Q2
Event_List(1,end+1)=1;
Event_List(2,end) = T + exprnd(1/Lambda);
Event_List(3,end) = Event_List(3,1);
    
end

function [T,Event_List, Sending_list, CAT, RAT, D, Senders_list, index]=Event2(T,Event_List, Sending_list, Q1, Q2, CAT, RAT, Channels, sync_time, Rtt, D, Nodes, Senders_list, index, Queue_Size)
%fprintf('\nevent 2 time %d\n', Event_List(2,1));
%disp('queues')
%disp('sending list before')
%disp(Sending_list)
T=Event_List(2,1);
%disp('cat before')
%disp(CAT)
%disp('rat before')
%disp(RAT)
wants2send = false;
sent_times = 0;
% create D matrix
for i = 1 : Queue_Size
    %fprintf('loop %d\n',i);
    if Q2(Event_List(3,1), i) ~= 0
        %disp('true')
        index(Event_List(3,1), i) = i;
        D(Event_List(3,1), Q2(Event_List(3,1), i)) = D(Event_List(3,1), Q2(Event_List(3,1), i)) + 1;
        wants2send = true;
    end
end
%disp('D')
%disp(D)
if wants2send == false
%    fprintf('node %d has nothing to send\n', Event_List(3,1));
elseif wants2send == true
    chosen_channel = 1; %find earliest avail channel
    for w = 2 : Channels
        if CAT(w) < CAT(chosen_channel)
            chosen_channel = w;
        end
    end
%    fprintf('sender %d\nchannel %d\n', Event_List(3,1), chosen_channel);
    %
    for i = 1 : Nodes %for each destination
        if D(Event_List(3,1), i) ~= 0
            number_of_packets = D(Event_List(3,1), i); %has the packets to send
            receiver = i; %the receiver of the packets

            r = RAT(receiver) + sync_time;
            %fprintf('r=%d\n', r);        
            t1 = max(CAT(chosen_channel), sync_time);
            %fprintf('t1=%d\n', t1);
            t2 = max(t1 + Rtt, r);
            %fprintf('t2=%d\n', t2);
            
            Sending_list(chosen_channel, (t2 - Rtt) : (t2 - Rtt - 1) + number_of_packets) = receiver; %update sending list
            Senders_list(chosen_channel, (t2 - Rtt) : (t2 - Rtt - 1) + number_of_packets) = Event_List(3,1);
            Sending_list(Channels + 1, (t2 - Rtt)) = T + (t2 - Rtt); %add the time 
            RAT(receiver) = t2 + number_of_packets; %update RAT
            CAT(chosen_channel) = t2 - Rtt + number_of_packets; %update CAT
           
            %disp('sending list after')
            %disp(Sending_list)
            %disp('senders list ater')
            %disp(Senders_list)
            %disp('rat after')
            %disp(RAT)
            %disp('cat after')
            %disp(CAT)
        else
            %fprintf('sender %d has nothing for receiver %d\n', Event_List(3,1), i);
        end 
    end
end
D(Event_List(3, 1), :) = 0;
end

function [T, Event_List] = Event3(T, Event_List, Sending_list, Senders_list, Channels, Nodes, Q1, Q2)
T = Event_List(2, 1);
%fprintf('\nevent 3 time %f\n', T);
L = size(Sending_list);
if L(2) > 1
    Sending_list(Channels + 1, 2 : end) = Sending_list(Channels + 1, 1) + (1 : L(2) -1); %mark the times
end

%disp(Sending_list)
for times = 1 : L(2) %run the times, hor
    Event_List(1, end + 1) = 4; %send event
    Event_List(2, end) = Sending_list(Channels + 1, times);   
end
            
Event_List(1, end + 1) = 3;
K = size(Sending_list);
if K(2) >= 1
    Event_List(2, end) = Sending_list(Channels + 1, end) + Nodes * 0.25;
else
    Event_List(2, end) = T + Nodes * 0.25;
end
Event_List(1, end + (1:Nodes)) = 2;
if K(2) >= 1
    Event_List(2, end - (0:Nodes - 1)) = Sending_list(Channels + 1, end) + 0.25 * (1:Nodes);
else
    Event_List(2, end - (0:Nodes - 1)) = T + 0.25 * (1:Nodes);
end
Event_List(3, end - (0:Nodes - 1)) = (1 : Nodes);
%disp('event list')
%disp(Event_List)
end

function [T, Event_List, Sending_list, Senders_list, Q1, Q2, index, CAT, RAT, Qtime, sent_packets] = Event4(T, Event_List, Sending_list, Senders_list, Q1, Q2, Channels, Queue_Size, index, CAT, RAT, Qtime, sent_packets)
T = Event_List(2, 1);
%fprintf('\nevent 4 time %f\n', T);
sender = 0;
%disp('initial values')

for ch = 1 : Channels
    if Sending_list(ch, 1) ~= 0 %someone is sending
        %fprintf('channel %d\n', ch);
        sender = Senders_list(ch, 1);
        
        recv_pos = 1;
        for j = 2 : Queue_Size
            %fprintf('loop %d\n', j);
            if (index(sender, j) < index(sender, recv_pos) && index(sender, j) ~= 0) || index(sender, recv_pos) == 0
                %disp('true')
        %        min_time = Q1(sender, j);
                recv_pos = j;
            end            
        end
        t = index(sender, recv_pos);
        index(sender, recv_pos) = 0;
        receiver = Sending_list(ch, 1);
        %fprintf('channel %d\n', ch);
        %Q2(sender, index(sender, recv_pos)) = 0;
        Qtime = Qtime + (T - Q1(sender, t));
        sent_packets = sent_packets + 1;
        Q2(sender, t) = 0;
        Q1(sender, t) = -1;
        %Q1(sender, index(sender, recv_pos)) = -1;
        
    end
end
Sending_list(:, 1) = [];
Senders_list(:, 1) = [];
CAT(1 : end) = 0;
RAT(1 : end) = 0;
end

function [T,flag]=Event10(T,flag,Event_List)

T=Event_List(2,1);
flag=false;

end
