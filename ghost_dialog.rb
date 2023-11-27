module CURIC
  module DialogTesting
    require 'json'

    # View Observer for the Ghost Dialog
    class GhostDialogObserver < Sketchup::ViewObserver
      def initialize(dialog)
        @dialog = dialog
      end

      def onViewChanged(view)
        UI.start_timer(view.last_refresh_time + 0.01, false) do
          @dialog.update
        end
      end
    end

    # Ghost Dialog
    class GhostDialog < UI::HtmlDialog
      def initialize(**options)
        super(default_options.merge(options))

        @view = Sketchup.active_model.active_view
        build
        show
      end

      def default_options
        {
          dialog_title: '👻👻👻',
          scrollable: false
        }
      end

      def build
        set_html(build_html)
        add_action_callback('call') { |*args| send(args[1].to_sym, *args[2..-1]) }

        @view_observer = GhostDialogObserver.new(self)
        @view.add_observer(@view_observer)
        set_on_closed { @view.remove_observer(@view_observer) }

        center
      end

      def build_html
        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <style>
                html, body {
                  height: 100%;
                }
                body {
                  margin: 0;
                  padding: 0;
                }
                .container {
                  position: relative;
                  display: flex;
                  justify-content: flex-end;
                  align-items: center;
                  flex-direction: column;
                  height: 100%;
                }
                img {
                  position: absolute;
                  top: 0;
                  left: 0;
                }
                button {
                  width: 75px;
                  height: 30px;
                  border: 1px solid #333;
                  border-radius: 5px;
                  background: rgba(190, 190, 190, 0.5);
                  color: #333;
                  z-index: 1;
                  margin-bottom: 10px;
                }
              </style>
            </head>
            <body>
              <div class="container">
                <img src="" alt="Image" id="image-preview">
                <button onclick="sketchup.call('close')">Close</button>
              </div>

              <script>
                var position = { x: window.screenX, y: window.screenY };

                function update(imageData) {
                  document.getElementById('image-preview').src = imageData.filename + '?t=' + Date.now();
                }
                function updateImagePosition(x, y) {
                  var image = document.getElementById('image-preview');
                  image.style.left = -x + 'px';
                  image.style.top = -y + 'px';
                }

                window.onload = () => sketchup.call('ready');
                window.addEventListener('resize', () => changed());

                function initTrace() {
                  setInterval(() => { 
                    if (position.x !== window.screenX || position.y !== window.screenY) {
                      changed();
                    }
                  }, 10);
                }

                function changed(){
                  position = { x: window.screenX, y: window.screenY };
                  sketchup.call('dialog_changed');
                }
              </script>
            </body>
          </html>
        HTML
      end

      def ready
        set_position(*relative_position)

        @origin = get_position

        update

        execute_script('initTrace();')

        # html backgroud color
        bg = Sketchup.active_model.rendering_options['BackgroundColor']
        color = "rgb(#{bg.red}, #{bg.green}, #{bg.blue})"
        execute_script("document.body.style.backgroundColor = '#{color}';")
      end

      def dialog_changed
        new_position = get_position
        moved_x = new_position.x - @origin.x
        moved_y = new_position.y - @origin.y
        execute_script("updateImagePosition(#{moved_x}, #{moved_y})")
      end

      def relative_position
        size = get_size
        position = get_position
        screen_size = [@view.vpwidth, @view.vpheight]

        x = position.x - (screen_size.x - size.x) / 2
        y = position.y - (screen_size.y - size.y) / 2

        if Sketchup.platform == :platform_osx
          y += 2
          # else
          # Not tested on Windows
        end

        [x, y]
      end

      def update
        execute_script("update(#{write_image.to_json})")
      end

      def write_image
        options = {
          filename: File.join(Sketchup.temp_dir, 'example.png'),
          source: :framebuffer,
          compression: 0.9,
          width: @view.vpwidth,
          height: @view.vpheight
        }
        @view.write_image(options)

        options
      end
    end
  end
end

# Usage:
# CURIC::DialogTesting::GhostDialog.new
