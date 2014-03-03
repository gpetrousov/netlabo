function [Throughput, queue_time, drop_packet_perc, averageQtime, drop_perc] = itdm( Sim_Time, Nodes, Channels, Queue_Size, Lambda, Packet_Size)

if Nodes <= Channels
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
Event_List=zeros(3,Nodes+2);
Event_List(1,1:Nodes)=1; % Arrival Event
Event_List(2,1:Nodes)=0;
Event_List(3,1:Nodes)=1:Nodes;
Event_List(1,Nodes+1) = 2;
Event_List(2,Nodes+1) = 0;
Event_List(1,end)=10; % Simulation End Event
Event_List(2,end)=Sim_Time;

Q1=zeros(Nodes,Queue_Size);
Q2=zeros(Nodes,Queue_Size);
Q1(1:Nodes, 1:Queue_Size) = -1;
Channel_list = zeros(Nodes, 1);
drop_packets=0;
total_packets=0;
sent_packets = 0;

Throughput=0;
queue_time = 0;

%%channels init
Channel_list(1:Channels) = (1:Channels);, %where 0 means no channel given for transmission
Channel_list = circshift(Channel_list, -1);
%%ends

%disp('init')
%disp('Channels')
%disp(Channel_list)
%disp('event_list')
%disp(Event_List)

while flag
    event=Event_List(1,1);
    %fprintf('time %d\n', Event_List(2,1));
    
    if event==1 %packet arrive    
        [T,Event_List,Q1,Q2,total_packets,drop_packets]=Event1(T,Event_List,Lambda,Q1,Q2,total_packets,drop_packets, Queue_Size, Nodes);
       
    elseif event==2        
        [T, Event_List, Channel_list]=Event2(T,Event_List, Channel_list);
    
    elseif event == 3 %transmit packets
        [Q1, Q2, T, Event_List, queue_time, sent_packets] = Event3(T, Event_List, Q1, Q2, Queue_Size, queue_time, sent_packets);
        
    elseif event == 4 %clear packet from Q after 1 time unit 
        [T, Event_List, Q1, Q2] = Event4(T, Event_List, Q1, Q2);
        
    elseif event==10
        [T,flag]=Event10(T,flag,Event_List);
        
    end
    
    Event_List(:,1)=[];
    Event_List=(sortrows(Event_List',[2,1]))';
    
end
%SIMULATION END%
drop_packet_perc = (drop_packets * 100) / total_packets;
fprintf('\nsimulation end')
fprintf('total packets %d\n', total_packets);
fprintf('successfully sent packets %d\n', sent_packets);
fprintf('packets dropped %d\n', drop_packets);
fprintf('packets left in queue %d\n', total_packets - sent_packets - drop_packets);
fprintf('drop packets percentage %.2f%%\n', (drop_packets * 100) / total_packets );
drop_perc = (drop_packets * 100) / total_packets;
fprintf('Throughput %.2f Bps\n', (Packet_Size * sent_packets)/Sim_Time); %Bytes
Throughput = (Packet_Size * sent_packets)/Sim_Time
fprintf('total queue time %.4f\n', queue_time);
fprintf('average queue time %.4f\n', queue_time / sent_packets);
averageQtime = queue_time / sent_packets;
end

function [T,Event_List,Q1,Q2,total_packets,drop_packets]=Event1(T,Event_List,Lambda,Q1,Q2,total_packets,drop_packets, Queue_Size, Nodes)
%disp('event 1:')
T=Event_List(2,1);
%fprintf('time %f\n',T);

total_packets=total_packets+1;
counter=1;
drop_flag=true;

while(counter<=Queue_Size)
    if Q1(Event_List(3,1),counter)== -1 && Q2(Event_List(3, 1), counter) == 0 %there is spot in senders queue
        %disp('got queue')    
        Q1(Event_List(3,1),counter)= T; %when the packet will be sent
        %Event_List(1,end + 1) = 3; %tries to send the packet
        %Event_List(2,end) = T; %time       
        destination_node = randi(Nodes);
        %fprintf('sender %d\n', Event_List(3,1));
        while destination_node == Event_List(3,1)
            destination_node=randi(Nodes);
        end
        %fprintf('reciever %d\n', destination_node);
        Q2(Event_List(3,1),counter)=destination_node; %where the packet will be sent to
        %Event_List(3, end) = Event_List(3, 1); %mark the sender
        drop_flag=false;
        break;
    end
    counter=counter+1;
end
if drop_flag==true
    drop_packets=drop_packets+1;
    %disp('packet drop')
end
%disp('Q1')
%disp(Q1)
%disp('Q2')
%disp(Q2)
Event_List(1,end+1)=1;
Event_List(2,end) = T + exprnd(1/Lambda);
Event_List(3,end) = Event_List(3,1);
    
end

function [T, Event_List, Channel_list]=Event2(T,Event_List, Channel_list) %changes the channels
%fprintf('event 2 time %d\n', Event_List(2,1));
%disp('channels before')
%disp(Channel_list)

T=Event_List(2,1);
Channel_list = circshift(Channel_list, 1); %distribute channels to stations
Event_List(1,end+1)=2;
Event_List(2,end) = T + 1;

%renew event 3 for those with a channel
j = find(Channel_list ~= 0); %find those with a channel
L = size(j);
if L(1) > 1 %many channels
    for i = 1: L(1)
        Event_List(1, end + 1) = 3; %send event
        Event_List(2, end) = T;
        Event_List(3, end) = j(i); %the chosen can send
    end
else % one channel 
    Event_List(1, end + 1) = 3; %sends evetn
    Event_List(2, end) = T;
    Event_List(3, end) = j;
end

%disp('channels after')
%disp(Channel_list)
end

function [Q1, Q2, T, Event_List, queue_time, sent_packets] = Event3(T, Event_List, Q1, Q2, Queue_Size, queue_time, sent_packets) %remove (transmit) packet every time slot
T = Event_List(2,1);
%fprintf('event 3 time %f\n', T);
%disp('queue before')
%Q1
%Q2
%fprintf('sender %d got channel\n', Event_List(3,1));
min_found = false;

val_pos = find(Q1(Event_List(3,1), :) == 0); %search for zeros if any
L = size(val_pos);
if L(2) == 0
    %disp('no zeros found')
    min_found = false;
else %zero found
    %disp('zero found')
    min_val = Q1(Event_List(3,1), val_pos);
    min_found = true;
end

if min_found == false %no zero value times in Q
    %find the miminum value in matrix
    %disp('going to find minimum manually')
    min_val = Q1(Event_List(3,1), 1);
    for i = 2 : Queue_Size %search for minimum value
        if((Q1(Event_List(3,1), i) < min_val) && (Q1(Event_List(3,1), i) ~= -1))
            min_val = Q1(Event_List(3,1), i);
            val_pos = i;
            min_found = true;
        elseif (min_val == -1) && (Q1(Event_List(3,1), i) ~=-1)
            min_val = Q1(Event_List(3,1), i);
            val_pos = i;
            min_found = true;
        elseif (Q1(Event_List(3,1), 1) ~= -1) && (min_found == false)
            min_val = Q1(Event_List(3,1), 1);
            min_found = true;
            val_pos = 1;
        end
    end
    %val_pos = find(min(Q1(Event_List(3,1), :)) & (Q1(Event_List(3,1), :) ~= -1)); %search for minimum non -1
end

if min_found == false %if all are -1
    %fprintf('station %d has nothing to send\n', Event_List(3,1));
elseif min_found == true
    sent_packets = sent_packets + 1;
    %fprintf('min time is %f\n', min_val);
    %fprintf('min val position %d,%d\n', Event_List(3,1), val_pos);
    queue_time = queue_time + (T - min_val); %update total Q time
    Q1(Event_List(3,1), val_pos) = -1; %zero the time
    Event_List(1, end+1) = 4;
    Event_List(2, end) = T + 1;
    Event_List(3, end) = Event_List(3,1); %sender
end

%disp('queue after')
%disp('Q1')
%disp(Q1)
%disp('Q2')
%disp(Q2)

end

function [T, Event_List, Q1, Q2] = Event4(T, Event_List, Q1, Q2)
T = Event_List(2, 1);
%fprintf('event 4 time %f\n', T);
%disp('q before')
%disp('Q2')
%disp(Q2)
j = find(Q1(Event_List(3,1),:)==-1);
Q2(Event_List(3,1), j) = 0; %clear queue
%disp('q after')
%disp('Q1')
%disp(Q1)
%disp('Q2')
%disp(Q2)

end

function [T,flag]=Event10(T,flag,Event_List)

T=Event_List(2,1);
flag=false;

end
