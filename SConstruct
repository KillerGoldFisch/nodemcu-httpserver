# scons -Q all

import datetime
vars = Variables()
vars.Add('PORT', 'Serial communication port', "COM3")
vars.Add('BAUD', 'Serial communication speed', 115200)
vars.Add('IP', 'IP-Adress for Telnet', "192.168.2.100")
vars.Add(EnumVariable('CONNECTION', 'Connection type', 'serial',
                      allowed_values=('serial', 'telnet'),
                      map={}, ignorecase=2))
vars.Add('datetime', '*', str(datetime.datetime.now()))
env = Environment(variables = vars)

import os, re, sys
import hashlib
#     ____        _ __    __         
#    / __ )__  __(_) /___/ /__  _____
#   / __  / / / / / / __  / _ \/ ___/
#  / /_/ / /_/ / / / /_/ /  __/ /    
# /_____/\__,_/_/_/\__,_/\___/_/     
                                   

import _tools.template as template
def template_builder_action(target, source, env):
    for i in range(len(source)):
        target_stream = open(str(target[i]), "w")
        target_stream.write(template.render(filename=str(source[i])))
        target_stream.close()
env['BUILDERS']['TemplateBuilder'] = Builder(action = template_builder_action)

def upload_builder_action(target, source, env):
    for i in range(len(source)):
        exit_code = os.system(sys.executable + ' _tools/nodemcu-uploader.py -b {0} -p {1} upload {2}'.format(
            env['BAUD'],
            env['PORT'],
            source[i]
            ))
        if exit_code != 0:
            raise Exception("Upload failed")
        else:
            open(str(target[i]), "w").close()
env['BUILDERS']['UploadBuilder'] = Builder(
        action = upload_builder_action
        #action=sys.executable + ' _tools/nodemcu-uploader.py -b $BAUD -p $PORT upload $SOURCE',
        )

#    __  ____  _ __    
#   / / / / /_(_) /____
#  / / / / __/ / / ___/
# / /_/ / /_/ / (__  ) 
# \____/\__/_/_/____/  


def re_glob(ldir, exp):
    return [os.path.join(ldir, f) for f in os.listdir(ldir) if re.match(exp, f)]

def tem_target(tem):
    if not tem.endswith(".tem"):
        raise Exception("No '.tem' file! :" + str(tem))
    return tem[:-4]


do_http = "http" in BUILD_TARGETS or 'all' in BUILD_TARGETS
do_server = "server" in BUILD_TARGETS or 'all' in BUILD_TARGETS

#   ______                     __      __     
#  /_  __/__  ____ ___  ____  / /___ _/ /____ 
#   / / / _ \/ __ `__ \/ __ \/ / __ `/ __/ _ \
#  / / /  __/ / / / / / /_/ / / /_/ / /_/  __/
# /_/  \___/_/ /_/ /_/ .___/_/\__,_/\__/\___/ 
#                   /_/                       

template_files = []

if do_http:
    template_files += [str(f) for f in env.Glob("*.tem")]

if do_server:
    template_files += [str(f) for f in env.Glob("http/*.tem")]

template_files_out = [tem_target(f) for f in template_files]

template_builder_action(template_files_out, template_files, env)


#    __  __      __                __
#   / / / /___  / /___  ____ _____/ /
#  / / / / __ \/ / __ \/ __ `/ __  / 
# / /_/ / /_/ / / /_/ / /_/ / /_/ /  
# \____/ .___/_/\____/\__,_/\__,_/   
#     /_/                            

upload_files = []

if do_server:
    upload_files += [
        'init.lua',
#        'config.lua',
#        'telnet.lua',
    ]
    upload_files += [str(f) for f in re_glob(".", "^httpserver.*\.lua$")]

if do_http:
    upload_files += [str(f) for f in re_glob("http", ".*(?!\.tem)$")]

for to in template_files_out:
    if to not in upload_files:
        upload_files.append(to)

#print upload_files
upload_files_out = [os.path.join("_tools/.dummys", hashlib.md5(x).hexdigest()) for x in upload_files]

for i in range(len(upload_files)):
    env.Alias('all', env.UploadBuilder(upload_files_out[i], upload_files[i]))
    env.Alias('server', env.UploadBuilder(upload_files_out[i], upload_files[i]))
    env.Alias('http', env.UploadBuilder(upload_files_out[i], upload_files[i]))
