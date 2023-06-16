1. First Time Use:

    You have to install Ruby if you do not already have it.
    https://www.ruby-lang.org/en/

    Next, you will need to install dependencies.
    ```
    bundle install
    ```

    Otherwise, open your terminal to run and open ruby terminal
    ```
    $ irb
    2.7.8 :001 >
    ```

    If you have windows, you can enter the following
    in the ruby terminal
    ```
    2.7.8 :001 > gem install rio
    2.7.8 :001 > gem install fileutils
    2.7.8 :001 > gem install nokogiri
    2.7.8 :001 > gem install twitter_cldr
    ```

2. To Run Tests:

    Go into the directory with the building tools
    and run the ruby program.
    >>> cd bjc-r/utilities/build-tools
    >>> irb -r ./tests.rb
    The above will open the ruby terminal. You will now need to pass in
    specific test functions. Look at the tests.rb file for specific tests.

    First initialize the testing object:
    3.2.2 :001 > t = Tests.new()
    3.2.2 :001 > t.[NameOfTestFunction]
    [NameOfTestFunction] being one of the functions as a parameter in the tests.rb file

    Example for running english CSP test:
    3.2.2 :001 > t = Tests.new()
    3.2.2 :001 > t.mainCSP()

    Example for running spanish CSP test:
    3.2.2 :001 > t = Tests.new()
    3.2.2 :001 > t.mainCSPSpanish()

3. To Run Curriculum pages:

    Go into the directory with the building tools
    and run the ruby program.
    $ cd bjc-r/utilities/build-tools

    The above will open the ruby terminal.
    Everything runs from main.rb using the main function and object

    First create the main object and then call the main function,
    which takes in the class curriculum folder, class topic folder
    and specified language as string inputs.

    Note, that the folders are local to your drive (i.e. C:/Users/I560638)
    3.2.2 :001 > myMain = Main.new(root: 'path-to/bjc-r/', cur_dir: 'cur/..', topic_dir: 'nyc_bjc', [language])
    3.2.2 :002 > myMain.main()

    Example for running english CSP:
    3.2.2 :001 > engCSP = Main.new(root: "C:/Users/I560638/bjc-r/", cur_dir: 'programming' topic_dir: "nyc_bjc", "en")
    3.2.2 :002 > engCSP.main()

     Example for running spanish CSP:
    3.2.2 :001 > esCSP = Main.new(root: "C:/Users/I560638/bjc-r/", cur_dir: "programming", topic_dir: "nyc_bjc", "es")
    3.2.2 :002 > esCSP.main()


4. General:

    To open a specific ruby file, enter the following with the [file]
    being a specified file name (parameter).
    >>> irb ./[file].rb
    To open a specific ruby file in interative mode.
    **There may be an issue with one of the ruby gems if you run this line in gitbash.
    >>> irb -r ./[file].rb


5. Running Locally:

    Once the summary pages have generated go to parent directory of bjc-r
    then load the localhost
    $ python -m http.server
