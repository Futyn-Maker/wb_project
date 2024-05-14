function getAnswer() {
    const question = document.getElementById("question").value;
    if (!question) {
        alert("Пожалуйста, задайте вопрос");
        return;
    }
    fetch(`/get_answer/?question=${encodeURIComponent(question)}`)
        .then(response => response.json())
        .then(data => {
            document.getElementById("answer").innerText = data.answer;
        })
        .catch(error => {
            console.error("Error:", error);
            alert("Во время обработки вопроса произошла ошибка");
        });
}
