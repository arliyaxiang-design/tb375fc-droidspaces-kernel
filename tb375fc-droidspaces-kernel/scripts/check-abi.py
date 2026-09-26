from pathlib import Path
import sys,json,re
p=Path(sys.argv[1])
def symbols(file):
    return {v[1]:v[0] for line in file.read_text().splitlines() if len(v:=line.split())>=2}
a=symbols(p/'baseline.Module.symvers');b=symbols(p/'droidspaces.Module.symvers')
missing=sorted(a.keys()-b.keys())
changed={s:[a[s],b[s]] for s in a.keys()&b.keys() if a[s]!=b[s]}
def size(file):
    text=file.read_text();m=re.search(r'/\* size: (\d+)',text)
    if not m:raise RuntimeError('Cannot parse task_struct size')
    return int(m[1])
report={'missing_baseline_exports':missing,'changed_export_crcs':changed,
        'task_struct_size_before':size(p/'baseline.task_struct.txt'),
        'task_struct_size_after':size(p/'droidspaces.task_struct.txt'),
        'limitation':'Same-build CRC checks are not proof of compatibility with stock vendor modules. Member offsets and signed GKI modules still require review.'}
(p/'abi-comparison.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert not missing and not changed,'Export CRCs changed'
assert report['task_struct_size_before']==report['task_struct_size_after'],'task_struct size changed'
