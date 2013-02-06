#
# Copyright (C) 2013-2013  Brandon Perkins <bperkins@redhat.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

""" Code for building Inspectorates docs and committing them. """

import os
from tito import builder
from tito import common

class CustomBuilder(builder.Builder):
    print ("Running custom builder...")

    def _rpm(self):
        super(CustomBuilder, self)._rpm()
        readme_md = os.path.join(self.git_root, "README.md")
        readme_md_rpm = common.run_command("rpm -qlp %s | grep README.md$" % self.artifacts[2])
        readme_md_git = common.run_command("rpm2cpio %s | cpio --quiet -idmuv .%s 2>&1" % (self.artifacts[2], readme_md_rpm))
        output = common.run_command("mv -v %s %s" % (readme_md_git, readme_md))
        print (output)
