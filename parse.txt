// v.length === 0 ? 0 : i === 0 ? `'${v}'`: v
(async () => {
  const parseLine = (a) =>
    a.replace(/"([0-9,]+)"/g, (_, p1) => p1.split(",").join(""));
  const fillVoid = (line) =>
    line.map((v, i) => {
      if (i === 0) {
        return `'${v}'`;
      }
      if (v.length === 0 || v.toLowerCase() === "n/a") {
        return "null";
      }
      return v;
    });
  const filterFields = [0, 1, 3, 5, 7];
  const filterFunc = (ar) => ar.filter((_, i) => filterFields.includes(i));
  const outputFile = require("fs").createWriteStream("./test.sql", {
    encoding: "utf8",
  });

  let rl = require("readline").createInterface({
    input: require("fs").createReadStream("./parse.csv"),
  });

  let first_line = true;
  for await (let line of rl) {
    if (first_line) {
      first_line = false;
      continue;
    }
    let f = filterFunc(fillVoid(parseLine(line).split(","))).join(",");
    outputFile.write(
      `insert into covid(country_name, total_cases, deaths, recovered, serious) values(${f});\n`
    );
  }
})();
