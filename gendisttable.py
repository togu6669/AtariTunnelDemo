import math

WIDTH = 40
HEIGHT = 24

cx = WIDTH / 2
cy = HEIGHT / 2

table = []

for y in range(HEIGHT):
    for x in range(WIDTH):
        dx = x - cx
        dy = y - cy
        
        dist = int(math.sqrt(dx*dx + dy*dy))
        
        # skalowanie do zakresu 0–15
        dist = dist % 16
        
        table.append(dist)

# konwersja do .BYTE
for i in range(0, len(table), 16):
    row = table[i:i+16]
    line = ".BYTE " + ",".join(str(v) for v in row)
    print(line)