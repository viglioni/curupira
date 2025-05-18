const HtmlWebpackPlugin = require("html-webpack-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");
const fs = require("fs");
const path = require("path");

const htmlDir = path.join(__dirname, "html");
const port = process.env.PORT || 4546;
const htmlFiles = fs
  .readdirSync(htmlDir)
  .filter((file) => file.endsWith(".html"));
const htmlPlugins = htmlFiles.map(
  (htmlFile) =>
    new HtmlWebpackPlugin({
      template: path.join("html", htmlFile),
      filename: htmlFile,
      chunks: ["main"],
    }),
);
const copyPlugin = new CopyWebpackPlugin({
  patterns: [{ from: "styles", to: "styles" }],
});

module.exports = (env, argv) => {
  const isProduction = argv.mode === "production";

  return {
    entry: "./js/index.js",
    mode: isProduction ? "production" : "development",
    devtool: isProduction ? "source-map" : "eval-source-map",
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          use: [
            {
              loader: "babel-loader",
              options: {
                presets: [["env", { modules: false }]],
              },
            },
            "ts-loader",
          ],
          exclude: /node_modules/,
        },
        {
          test: /\.s[ac]ss$/i,
          use: ["style-loader", "css-loader", "sass-loader"],
        },
      ],
    },
    resolve: {
      extensions: [".tsx", ".ts", ".js"],
    },
    output: {
      filename: isProduction ? "[name].[contenthash].js" : "bundle.js",
      path: path.resolve(__dirname, "dist"),
      clean: true,
    },
    devServer: {
      static: {
        directory: path.join(__dirname, "dist"),
      },
      compress: true,
      port,
      hot: true,
    },
    plugins: [...htmlPlugins, copyPlugin],
    optimization: {
      minimize: isProduction,
    },
  };
};
