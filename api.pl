#!/usr/bin/perl -w
use strict;

my $base_path = $ENV{"HOME"}."/.projectdata";
#===========================functions definitions=============================

sub printUage()
{
    print "usage:\n";
    print "vit <op> <args...>\n";
    print "<op>:\n";
    print "create c:create a new project,with a project name and  an absolute path\n";
    print "delete d:delete the object.All data files will be deleted\n";
    print "open o:open a project\n";
    print "update u:update a project\n";
}

# @description: clear all project-related files and dir
# @param name:  project name
# @return: result code
sub clear()
{
    my $name = $_[0];
    #open(MYFILE, "< $basedir/projects") or die "$!\n";
    #open(SWPFILE, "> $basedir/~projects.swap") or die "$!\n";

    #while(<MYFILE>)
    #{
    #    if(m/$_[0] .*/)
    #    {
    #        next;
    #    }
    #    print SWPFILE $_;
    #}
    #system("rm -rf $basedir/projects && mv $basedir/~projects.swap $basedir/projects");

    #rmdir("$basedir/$_[0]") or die "$!\n";
    #system("rm -rf $basedir/$_[0]");

    #close(MYFILE);

    #return 0;
    (! -d "$base_path/$name") || system "rm -rf $base_path/$name";

    #return $?;
}

# @description: clean all the project-related data files
# @param name: project name
# @return:result code
sub clean()
{
    my $name = $_[0];
    #my $datadir = "$basedir/$_[0]";

    #opendir(DIR, $datadir) or die "$!\n";

    #while(my $file = readdir(DIR))
    #{
    #    if(-f "$datadir/$file")
    #    {
    #        unlink "$datadir/$file";
    #    }
    #}

    #closedir(DIR);

    #return 0;
    system "rm -rf $base_path/$name/cscope.* $base_path/$name/tags";
    #return $?;
}

# @description :parse FROM source dir TO data dir
# @param name  :TO - project name
# @param path  :FROM - project source path
sub parseProject()
{
    my ($name, $path) = @_;
   
    my $tmp;
    my $cmd_str;
    my @excldir;
    my @exclfiletype;

    #test if the project has existed
    if(! -d "$base_path/$name" )
    {
        print "Parsing failure:no project dir\n";
        return 1;
    }

    if(system "touch $base_path/$name/cscope.files")
    {

        print "Parsing error:creating file "
        . "$base_path/$name/cscope.files failure\n";

        &clear($name);
        return 1;
    }

    @excldir = &get_conf_section("$base_path/$name/path_info", 'excluded_path');
    @exclfiletype = &get_conf_section("$base_path/$name/path_info", 'excluded_filetype');

    # = contruct the find string
    $cmd_str .= "find $path ";

    # cmd_str:exclude specified directory
    if(@excldir == 0)
    {
        foreach(@excldir)
        {
            $cmd_str .= " -path \"$path/$_\" -prune -o ";
        }
    }

    # cmd_str:exclude specified filetype
    my $flag;
    foreach(('c', 'cc', 'cpp', 'h', 'inl', 's', 'S', 'x', 'js'))
    {
        $flag = 0;
        $tmp = $_;
        if(@exclfiletype == 0)
        {
            foreach(@exclfiletype)
            {
                if($_ eq $tmp)
                {
                    $flag = 1;
                }
            }
        }

        if($flag != 1)
        {
            $cmd_str .= " -name \"*.$tmp\" -o ";
        }
    }

    # chop the last '-o ' and append other options
    chop $cmd_str;
    chop $cmd_str;
    chop $cmd_str;

    chdir("/"); # To let 'find' parse out with absolute path

    if(system "$cmd_str > $base_path/$name/cscope.files" || die "Parsing error:find failure\n")
    {
        print "Parsing failure:find failure\n";
        &clear($name);
        return 1;
    }
    if(system "cscope -bkq -i $base_path/$name/cscope.files -f $base_path/$name/cscope.out")
    {
        print "Parsing failure:cscope failure\n";
        &clear($name);
        return 1;
    }
    if(system "ctags -R -f $base_path/$name/tags $path")
    {
       print "parsing error:ctags error\n";
       &clear($name);
       return 1;
    }
}

# @brief :get configuration section from a conf file
# @param file :file name
# @param secname :section name
# @return :undef if not found, array for the found
sub get_conf_section
{
    my ($file, $secname) = @_;
    my ($key, $value);
    my @arr;
    my %conf;

    %conf = &parse_conf("$file");

    while(($key, $value) = each %conf) 
    {
        if($key eq $secname)
        {
            return @{$value};
        }
    }
    
    return undef;
}

# @brief :update the value of specified section
# @param file :file name
# @param secname :section name
# @param values(ref to array) :new values used 
#                              to update section
# @return :0 for success
sub set_conf_section
{
    my ($file, $secname, $value) = @_;
    my %content;
    my ($key, $val);

    %content = &parse_conf($file);

    open FILE, ">$file" or return 1;


    while(($key, $val) = each %content)
    {
        # = edit the specified section
        if($key eq $secname)
        {
            $content{$key} = $value;
        }

        # = print everything to file
        print FILE "$key\n";
        foreach(@{$content{$key}})
        {
            print FILE "$_\n";
        }
        next;
    }

    close(FILE);

    return 0;
}

# @brief :read conf file and parse as hash
# @param file :conf file name
# @return :number for error,content as hash parsed from file
sub parse_conf
{
    my ($file) = @_;
    my %content;
    my ($key, $tem_value);

    open FILE, $file or return undef;

    while(<FILE>)
    {
        chomp $_;

        if(m/\[(.*)\]/)
        {
            $key = $1;
            $content{$key} = undef;
            $tem_value = [];
            next;
        }

        if(defined($tem_value))
        {
            push @{$tem_value}, $_;
            $content{$key} = $tem_value;
        }
    }

    return %content;
}
