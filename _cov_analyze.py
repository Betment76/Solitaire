import re

files = {}
current = None
with open('coverage/lcov.info') as f:
    for line in f:
        line = line.strip()
        if line.startswith('SF:'):
            current = line[3:]
        elif line.startswith('LF:') and current:
            files[current] = {'lf': int(line[3:]), 'lh': 0}
        elif line.startswith('LH:') and current:
            files[current]['lh'] = int(line[3:])

total_lf = 0
total_lh = 0
for path, d in sorted(files.items(), key=lambda x: x[1]['lh'] / max(x[1]['lf'], 1)):
    cov = d['lh'] / max(d['lf'], 1) * 100
    short = path.replace('F:\\Programs\\AndroidStudioProject\\solitaire\\', '')
    print(f'{cov:5.1f}% {d["lh"]:4d}/{d["lf"]:4d}  {short}')
    total_lf += d['lf']
    total_lh += d['lh']

print(f'\nTOTAL: {total_lh/total_lf*100:.1f}% ({total_lh}/{total_lf})')
