---
layout: post
title: "Microservices: the complete saga"
description: Deze blog gaat over compensating transactions en het saga pattern toegepast in een microservice-architectuur.
date: 2021-10-08 17:00:00 +0200
---

In deze blog beschrijf ik een manier om gedistribueerde transacties toe te passen in een microservice-architectuur met behulp van het [saga pattern](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga) en het [compensating transactions pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction).

Allereerst leg ik de aanleiding voor deze blog uit door te bespreken waarom transacties en microservices niet vanzelfsprekend hand-in-hand gaan. Daarna licht ik toe wat compensating transactions en het saga pattern precies inhouden, waarna ik een voorbeeldimplementatie van het saga pattern laat zien.

Deze blog is geschreven in opdracht van de [Hogeschool van Arnhem en Nijmegen](https://tweakers.net/nieuws/187748/han-rondt-onderzoek-datalek-af-ruim-14000-gevoelige-gegevens-gestolen.html) tijdens de [Minor DevOps](https://www.han.nl/nieuws/2021/07/nieuwe-it-minor-devops-van-start/index.xml).

## Transacties en microservices

Het gebruik van transacties in een database is een welbekende en veelgebruikte techniek om een aantal samenhangende operaties uit te voeren die óf allemaal slagen óf allemaal falen. Een belangrijk aspect van een transactie is dat deze atomair is. Dit houdt in dat de data die een transactie aanpast pas in de database *gecommit* wordt op het moment dat de transactie succesvol is afgerond. Een "half-afgeronde" transactie bestaat dus niet. (Microsoft, 2018)

Het gebruik van een microservice-architectuur biedt op veel vlakken voordelen. Helaas bemoeilijkt het gedistribueerde karakter van microservices het gebruik van transacties enorm. Sterker nog, het is meestal onmogelijk om een *ACID*-compliant transactie over verschillende microservice-databases uit te voeren. (Microsoft, z.d.)

Er zijn verschillende strategieën om transacties toe te passen in een microservice-architectuur. In dit artikel richt ik me op het saga pattern met compensating transactions. Het is belangrijk om te noemen dat deze transacties nog steeds niet ACID-compliant zijn. "Atomicity" en "Isolation" kunnen meestal niet gegarandeerd worden. In plaats daarvan zijn de transacties *BASE*-compliant:

- **B**asically **A**vailable
- **S**oft state
- **E**ventually consistent

Hierbij is vooral het concept "eventual consistency" belangrijk. Dit concept houdt in dat een wijziging niet direct zichtbaar is, maar na verloop van tijd wel gegarandeerd overal doorgevoerd wordt. (ScyllaDB, 2021)

## Compensating transactions

Als je gedistribueerde transacties gaat implementeren wordt het concept van compensating transactions erg belangrijk. Een compensating transaction is een **idempotente** actie die precies het tegenovergestelde doet van een bepaalde stap in de transactie. Elke actie binnen een transactie heeft dan ook een eigen compensating action (Microsoft, 2017). Dit is een voorbeeld van een gedistribueerde transactie:

![](/assets/images/microservices-the-complete-saga/compensating-transactions.drawio.svg)

Als voorbeeld gebruik ik een fictieve reisorganisatie. Een klant kan hier een (volledig willekeurige) reis boeken. Om dit te bereiken moet er met drie services gecommuniceerd worden. Als er een stap mislukt wordt de compensating action van die stap aangeroepen. Als er bijvoorbeeld iets misgaat bij het reserveren van de huurauto wordt de reservering geannuleerd en de vlucht geannuleerd. Het systeem bevindt zich dan weer in de staat waarin het zich voor het begin van de transactie bevond.

Uit dit diagram blijkt ook het belang van **idempotentie**. Het is namelijk ook mogelijk dat een compensating action faalt. Het is dus erg belangrijk dat de actie net zo lang herhaald kan worden tot deze slaagt.

## Saga pattern

Een manier waarop je gedistribueerde transacties met compensating transactions kan implementeren is met behulp van het saga pattern (IBM, z.d.). Je kan het saga pattern op twee manieren implementeren, namelijk choreography-based en orchestration-based (Richardson, z.d.). Beide strategieën hebben voor- en nadelen. [Dit](https://www.youtube.com/watch?v=xDuwrtwYHu8) is een interessante talk van Caitie McCaffrey over het toepassen van het saga pattern voor het verwerken van statistieken van de game Halo. Caitie heeft het hier specifiek over een orchestration-based saga.

### Choreography-based

De choreography-based saga is de meest eenvoudige manier om het saga pattern te implementeren. In deze situatie "weet" elke service wat de volgende stap in de transactie is. Nadat een service zijn stap succesvol heeft uitgevoerd is hij zelf verantwoordelijk voor het aanroepen van de volgende service. Hetzelfde geldt voor een niet-succesvol afgeronde stap. De service voert zijn eigen compensating action uit en roept de volgende compensating action aan. De architectuur van een choreography-based saga ziet er dus precies uit zoals het plaatje hierboven (Microsoft, z.d.).

Het voordeel van een choreography-based saga is dat het eenvoudig te implementeren is in een kleine architectuur. Er is geen single point of failure, elke service heeft namelijk evenveel verantwoordelijkheid bij het uitvoeren van de transactie. Een nadeel is echter dat het lastig te traceren is waar de transactie zich op dit moment bevindt. Ook het uitbreiden of wijzigen van een transactie wordt al snel complex (Richardson, z.d.).

### Orchestration-based

Een orchestration-based saga introduceert een nieuw concept: de orchestrator of saga execution coordinator (SEC). De SEC houdt alle transacties bij, weet welke stappen er volgen en in welke staat een transactie zich bevindt. De orchestrator is verwantwoordelijk voor het aanroepen van services, maar dus ook het uitvoeren van de compensating transaction wanneer een actie faalt. Het voordeel van deze gecentraliseerde aanpak is dat het een stuk makkelijker is om uit te vinden in welke staat een transactie zich bevindt. De SEC houdt dit namelijk precies bij. Daarnaast is het uitbreiden of wijzigen van een transactie eenvoudiger, aangezien dit alleen in de saga execution coordinator aangepast hoeft te worden. Het nadeel is dat er een single point of failure geïntroduceerd wordt (Richardson, z.d.). 

![](/assets/images/microservices-the-complete-saga/saga-execution-coordinator.jpeg)

De SEC kan je als losse service deployen. Een andere optie is om deze in een andere service te embedden. Dit kan bijvoorbeeld de eerste service in een transactie zijn.

## Voorbeeldimplementatie

Om een voorbeeld te demonstreren van een saga gebruik ik mijn eerdere voorbeeld van een fictief reisbureau. [De voorbeeldcode kan je hier vinden](https://github.com/ysbakker/saga-reisbureau). Instructies voor het uitvoeren staan in de [README](https://github.com/ysbakker/saga-reisbureau#uitvoeren). De architectuur ziet er als volgt uit:

*NB: Ik gebruik RabbitMQ om tussen services te communiceren. Het gebruik van een message queue is geen vereiste bij het gebruik van het saga pattern. Ik gebruik het hier wel omdat dat gebruikelijk is bij een microservice-architectuur.*

![](/assets/images/microservices-the-complete-saga/SagaImplementation.drawio.svg)

![](/assets/images/microservices-the-complete-saga/compensating-transactions.drawio.svg)

Vanwege de grootte van deze architectuur kies ik ervoor om gebruik te maken van een choreography-based saga. Dit is de flow van de transactie:
1. De controller van `ReisAPI` start een transactie op het moment dat iemand POST naar `/reizen`
2. De `TicketService` boekt een vliegticket
3. De `HuurautoService` reserveert een huurauto
4. De `HotelService` boekt een hotel

Wanneer er iets fout gaat in een service zal de service eerst zijn eigen actie compenseren, waarna hij de compenserende actie van de vorige service aanroept. Zo ziet het begin van de transactie in `ReisAPI` ([`ReizenController.cs`](https://github.com/ysbakker/saga-reisbureau/blob/master/ReisAPI/Controllers/ReizenController.cs)) er uit:

```cs
using (connection)
{
    using var channel = connection.CreateModel();
    channel.ExchangeDeclare("saga", ExchangeType.Topic, true);
    Message message = new() 
    {
        Id = Guid.NewGuid().ToString()
    };
    channel.BasicPublish("saga", "saga.ticketservice.execute", null,
        Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message)));
}
```

De `ReisAPI` publiceert een nieuw bericht op het *saga* topic met routing key *saga.ticketservice.execute*. Op het moment dat het uitvoeren van de actie foutgaat zal de service zijn actie ongedaan maken. Indien er een vorige stap in de transactie was zal de service een bericht publiceren met routing key *saga.[servicenaam].compensate*. Op die manier hoeft een service dus alleen aan de topic *saga.[servicenaam].\** te binden. Deze strategie zorgt er ook voor dat een eventuele uitbreiding naar een gecentraliseerde aanpak een stuk makkelijker wordt. Deze service hoeft dan alleen aan de topic *saga.\*.\** te binden.

Elke service heeft een `Execute()` methode, in dit geval om duidelijk te maken dat dat de stap in de transactie is die uitgevoerd wordt:

```cs
async Task Execute(Message message)
{
    Console.WriteLine($"Started executing HotelService for {message.Id}");
    await collection.InsertOneAsync(message);
    var rand = new Random();
    if (rand.Next(10) < 7) throw new Exception();
    Console.WriteLine($"Executed HotelService for {message.Id}");
    Next(message);
}
```

De `Execute()` methode van `HotelService` ([`HotelService/Program.cs`](https://github.com/ysbakker/saga-reisbureau/blob/master/HotelService/Program.cs)) simuleert (in 70% van de gevallen) een fout in het uitvoeren, waarna door een bovenliggende `try/catch` de compenserende actie wordt aangeroepen. Dat is in dit geval het ongedaan maken van de `Insert` in de database.

Daarnaast krijgt elke service een `Next()` methode, deze wordt aangeroepen zodra de stap in de transactie van die service voltooid is. Elke service weet dus wat de volgende stap in de transactie is, en publiceert in dit geval een nieuw bericht op de message queue.

```cs
void Next(Message message)
{
    channel.BasicPublish("saga", "saga.hotelservice.execute", null,
        Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message)));
}
```

Uiteraard heeft elke service ook een manier om zijn actie te compenseren en terug te gaan naar de vorige stap in de transactie. De methode `Compensate()` maakt de actie ongedaan en `Previous()` roept de vorige service aan:

```cs
async Task Compensate(Message message)
{
    Console.WriteLine($"Started compensating HuurautoService for {message.Id}");
    var rand = new Random();
    if (rand.Next(10) < 7)
    {
        Console.WriteLine($"Compensation of HuurautoService failed for {message.Id}! Retrying...");
        throw new Exception();
    }
    await collection.DeleteOneAsync(document => document.Id == message.Id);
    Console.WriteLine($"Compensated HuurautoService for {message.Id}");
    Previous(message);
}

void Previous(Message message)
{
    channel.BasicPublish("saga", "saga.ticketservice.compensate", null,
        Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message)));
}
```

In dit geval simuleert `HuurautoService` ([`HuurautoService/Program.cs`](https://github.com/ysbakker/saga-reisbureau/blob/master/HuurautoService/Program.cs)) het falen van een compensating action. De aanroep van de `Compensate()` actie ziet er zo uit:

```cs
await Policy
    .Handle<Exception>()
    .WaitAndRetryForeverAsync(i => TimeSpan.FromSeconds(1))
    .ExecuteAsync(async () => await Compensate(parsed!));
```

Wanneer de compensating action faalt zal deze net zolang herhaald worden tot 'ie slaagt. Ik heb [Polly](https://github.com/App-vNext/Polly) gebruikt voor deze foutafhandeling. Als een transactie succesvol wordt afgerond zien de logs er zo uit:

```
reisapi_1             | Started transaction 1670771a-29ca-4d53-a5e9-e46f913529a5
ticketservice_1       | Started executing TicketService for 1670771a-29ca-4d53-a5e9-e46f913529a5
ticketservice_1       | Executed TicketService for 1670771a-29ca-4d53-a5e9-e46f913529a5
huurautoservice_1     | Started executing HuurautoService for 1670771a-29ca-4d53-a5e9-e46f913529a5
huurautoservice_1     | Executed HuurautoService for 1670771a-29ca-4d53-a5e9-e46f913529a5
hotelservice_1        | Started executing HotelService for 1670771a-29ca-4d53-a5e9-e46f913529a5
hotelservice_1        | Executed HotelService for 1670771a-29ca-4d53-a5e9-e46f913529a5
hotelservice_1        | Completed transaction 1670771a-29ca-4d53-a5e9-e46f913529a5
```

Elke service voert dus zijn eigen stap uit en "geeft het stokje door" naar de volgende service in de transactie. Wanneer er iets fout gaat ziet het er zo uit:

```
reisapi_1             | Started transaction 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
ticketservice_1       | Started executing TicketService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
ticketservice_1       | Executed TicketService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
huurautoservice_1     | Started executing HuurautoService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
huurautoservice_1     | Executed HuurautoService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
hotelservice_1        | Started executing HotelService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
hotelservice_1        | Started compensating HotelService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
hotelservice_1        | Compensated HotelService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
huurautoservice_1     | Started compensating HuurautoService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
huurautoservice_1     | Compensation of HuurautoService failed for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae! Retrying...
huurautoservice_1     | Started compensating HuurautoService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
huurautoservice_1     | Compensation of HuurautoService failed for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae! Retrying...
huurautoservice_1     | Started compensating HuurautoService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
huurautoservice_1     | Compensated HuurautoService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
ticketservice_1       | Started compensating TicketService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
ticketservice_1       | Compensated TicketService for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae
ticketservice_1       | Compensated transaction for 0674aa00-5aec-4c5e-b265-b7db47d9f1ae successfully.
```

In dit geval gaat er iets fout in `HotelService`. De service maakt eerst zijn eigen actie ongedaan en roept vervolgens de compensating action van `HuurautoService` aan. Deze gaat vervolgens fout en wordt net zo lang herhaald totdat hij slaagt. Uiteindelijk is de compensating transaction afgerond en is alle data die in de database was opgeslagen nu weer verwijderd. Dit kan je verifiëren door naar `localhost:8081` te gaan en de `TicketService` database te bekijken. Hier staan alleen documenten waarvan de gehele transactie is geslaagd.

## Conclusie

Het is relatief eenvoudig om het saga pattern toe te passen in een bestaande microservice-architectuur. In veel gevallen zal het echter niet zo eenvoudig zijn als mijn voorbeeldimplementatie. In een complexere architectuur met veel verschillende transacties is het waarschijnlijk beter om voor een gecentraliseerde aanpak, het orchestrated saga pattern te kiezen. Deze blog biedt echter een goede basis voor het begrip en implementeren van compensating transactions en het saga pattern.

## Bronvermelding

Microsoft (2018, 31 mei). What is a Transaction? - Win32 apps. Microsoft Docs. https://docs.microsoft.com/en-us/windows/win32/ktm/what-is-a-transaction

Microsoft. (z.d.). Saga distributed transactions - Azure Design Patterns. Microsoft Docs. Geraadpleegd op 6 oktober 2021, van https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga

ScyllaDB. (2021, 23 juni). What is Eventual Consistency? Definition & FAQs. https://www.scylladb.com/glossary/eventual-consistency/

Microsoft. (2017, 23 juni). Compensating Transaction pattern - Cloud Design Patterns. Microsoft Docs. https://docs.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction

IBM. (z.d.). Solving distributed transaction management problem in microservices architecture using Saga. IBM Developer. Geraadpleegd op 7 oktober 2021, van https://developer.ibm.com/articles/use-saga-to-solve-distributed-transaction-management-problems-in-a-microservices-architecture/#

Richardson, C. (z.d.). Sagas. microservices.io. Geraadpleegd op 7 oktober 2021, van https://microservices.io/patterns/data/saga.html