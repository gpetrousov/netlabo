function [] = plot3()

Queue_Size = [(1 : 10)];
L = size(Queue_Size);
drop_perc = zeros(1,L(2));


%parfor (i = 1 : L(2), 7)
for i = 1 : L(2)
    %fprintf('hello from thread %d\n', i);
    [Throughput, queue_time, drop_packet_perc, averageQtime, drop_perc(i)] = itdm( 10000, 10, 5, Queue_Size(i), 0.5, 1500);
    %fprintf('hello from thread %d\n', i);
end

plot(drop_perc(1 : end), Queue_Size(1:end), '-o');
xlabel('drop perc');
ylabel('Queue_Size');

end

